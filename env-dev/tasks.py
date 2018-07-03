import os
import sys
import json
import glob
import logging
import re, shutil, tempfile
from invoke import run
from invoke import task
from io import StringIO
from python_terraform import *
from subprocess import PIPE, Popen
import itertools
import time
import threading

# Uncomment to turn on command debugging
#logging.basicConfig(level=logging.DEBUG)

# Note for a given tf.CMD the following shows how to pass variables (var=) to terraform as part of the command line that is passed
# ie. passing env=prd
# tfplanout = tf.plan(no_color=IsNotFlagged, capture_output=False, out=planout, var_file=varfile, var={'env':'prod'})

def confirm(prompt=None, resp=False):
    """prompts for yes or no response from the user. Returns True for yes and
    False for no.

    'resp' should be set to the default value assumed by the caller when
    user simply types ENTER.

    >>> confirm(prompt='Create Directory?', resp=True)
    Create Directory? [y]|n:
    True
    >>> confirm(prompt='Create Directory?', resp=False)
    Create Directory? [n]|y:
    False
    >>> confirm(prompt='Create Directory?', resp=False)
    Create Directory? [n]|y: y
    True

    """

    if prompt is None:
        prompt = 'Confirm'

    if resp:
        prompt = '%s [%s]|%s: ' % (prompt, 'y', 'n')
    else:
        prompt = '%s [%s]|%s: ' % (prompt, 'n', 'y')

    while True:
        ans = input(prompt)
        if not ans:
            return resp
        if ans not in ['y', 'Y', 'yes', 'Yes', 'n', 'N', 'no', 'No']:
            print('please enter Yes or No.')
            continue
        if ans == 'y' or ans == 'Y' or ans == 'yes' or ans == 'Yes':
            return True
        if ans == 'n' or ans == 'N' or ans == 'no' or ans == 'No':
            return False

def cmdline(command):
    process = Popen(
        args=command,
        stdout=PIPE,
        shell=True
    )
    return process.communicate()[0]

def replace_all(text, dic):
    for y, z in dic.items():
        text = text.replace(y, z)
    return text

def findnreplace(file, subdict):
    with tempfile.NamedTemporaryFile(mode='w', dir='.', delete=False) as tmp, \
          open(file, 'r') as f:
        while f:
            line = f.readline()
            n = len(line)
            if n == 0:
                break
            newline = replace_all(line, subdict)
            tmp.write(newline)
        f.close()
        tmp.close()
    os.replace(tmp.name, file)

class Spinner(object):
    spinner_cycle = itertools.cycle(['-', '/', '|', '\\'])

    def __init__(self):
        self.stop_running = threading.Event()
        self.spin_thread = threading.Thread(target=self.init_spin)

    def __next__(self):
        pass

    def start(self):
        self.spin_thread.start()

    def stop(self):
        self.stop_running.set()
        self.spin_thread.join()

    def init_spin(self):
        while not self.stop_running.is_set():
            sys.stdout.write(self.spinner_cycle.__next__())
            sys.stdout.flush()
            time.sleep(0.25)
            sys.stdout.write('\b')

def azurelogout():
    azlogout = run('az logout', hide=True, warn=True)
    azlogoutstdout = StringIO(azlogout.stdout.strip())
    azlogoutstderr = StringIO(azlogout.stderr.strip())
    if azlogoutstdout.read() == '':
        print('Azure logout successful')
        return True
    elif azlogoutstderr.read() == 'ERROR: There are no active accounts.':
        print('No active Azure sessions')
        return True
    else:
        #azloginjson = json.load(StringIO(azlogout.stdout.strip()))[0]
        print(azlogout.stdout.strip())
        print(azlogout.stderr.strip())
        return False

def azurelogin():
    credsjson = 'azcreds.json'
    with open(credsjson, 'r') as handle:
        config = json.load(handle)
    spinner = Spinner()
    spinner.start()
    azlogin = run(('az login --service-principal --username %s --password %s --tenant %s') % (config["aad_client_id"], config["aad_client_secret"], config["tenant_id"]), hide=True, warn=True)
    spinner.stop()
    azloginio = StringIO(azlogin.stdout.strip())
    azloginjson = json.load(azloginio)[0]
    if azloginjson['state'] == 'Enabled':
        print('Azure login via service principal "%s" succeeded.' % (config["aad_client_id"]))
        return (config["aad_client_id"], config["aad_client_secret"], config["tenant_id"], azloginjson['id'])
    else:
        print('Service principal login unsuccessful, please ensure credentials in azcreds.json are correct.')
        print(azlogin.stderr.strip())
        return False

def azureloggedin():
    azstatus = run('az account show', hide=True, warn=True)
    azstatusio = StringIO(azstatus.stdout.strip())
    azstatusjson = json.load(azstatusio)
    if azstatusjson['state'] == 'Enabled':
        return True
    else:
        print('Not currently logged in to Azure. Please log in and retry.')
        print(azstatus.stderr.strip())
        return False

def clear():
    _ = os.system('clear')

@task
def envinit(ctx):
    """intial environment preparation"""
    azurelogout()
    print('Logging into Azure using credentials provided via azcreds.json...')
    aad_client_id, aad_client_secret, tenant_id, subscription_id = azurelogin()
    print('')
    print('Create new or enter existing resource group for OpenShift deployment...')
    rg2use, loc2use = createresourcegroup(ctx)
    print('')
    print('Create storage account to hold Terraform-state storage containers.')
    print('Storage account names are scoped globally (across subscriptions).')
    print('and should be between 3 and 24 characters, lowercase letters and numbers.')
    print('Example: tfstateocp001')
    stac2use = createstorageaccount(ctx, resourcegroup=rg2use, location=loc2use)
    spinner = Spinner()
    spinner.start()
    stackeycmd = run(('az storage account keys list --resource-group %s --account-name %s') % (rg2use, stac2use), hide=True, warn=True)
    spinner.stop()
    stackeyio = StringIO(stackeycmd.stdout)
    stackeyjson = json.load(stackeyio)[0]
    stackey2use = stackeyjson['value']
    print('')
    print('Choose a project name that will be used as the base naming convention throughout')
    print('the project.  It will be used as the base name for storage containers, virtual')
    print('machine names, project object tags, etc. It should be short, yet somewhat')
    print('descriptive and should consist of alphanumeric characters only. For example,')
    print('given a company "Acme Co." and this being a Red Hat OCP deployment, something')
    print('along the lines of \'acmeocp001\' is suggested.')
    while True:
        azprojectname = input("Please enter desired project name > ")
        ansrStr = str(confirm(prompt='You entered "'+azprojectname+'" as the desired base project name. Is this correct?'))
        if ansrStr == 'True':
            break
        else:
            print('Try again')
            continue
    # create bootstrap tfstate storage container
    bootstrapstcntr = createstoragecontainer(ctx, stacname=stac2use, stcontname=azprojectname+'-bootstrap')
    if aad_client_id != "False":
        print('')
        print('Performing initial environment preparation steps...')
        print('Copying sample tfvars into place...')
        rootDir=os.getcwd()
        baseprojectdir, envdir = os.path.split(os.getcwd())
        #sampletfvar = glob.glob('0*.sample')
        sampletfvar = []
        for filename in glob.iglob('**/*.sample', recursive=True):
            if 'azcreds.json.sample' not in filename:
                sampletfvar.append(filename)
        for i in reversed(range(len(sampletfvar))):
            print('Copying %s to %s' % (sampletfvar[i],os.path.splitext(sampletfvar[i])[0]))
            shutil.copy(sampletfvar[i],os.path.splitext(sampletfvar[i])[0])
        # 00beconf1.tfvars in env-<dev/qa/prod> root
        sublocs = ['resourcegroupname',
                'tfstatestorageaccountname',
                'tfstatestorageaccountkey']
        provided = [rg2use,
                    stac2use,
                    stackey2use]
        subdict = dict(zip(sublocs, provided))
        findnreplace(baseprojectdir+'/'+envdir+'/00beconf1.tfvars', subdict)
        # tfvars file symlinks
        realtfvars = glob.glob('*.tfvars')
        tierlist = [ 'bastion', 'bootstrap', 'crsapp', 'crsreg', 'infra', 'master', 'network', 'network-crs', 'node', 'openvpn']
        print('')
        print('Setting tfvars file symlinks to appropriate %s tier component locations,' % envdir)
        print('as well as defining tier component specific Terraform state storage container')
        print('definitions...')
        for tier in range(len(tierlist)):
            print('Creating tfvars symlinks in %s...' % (tierlist[tier]))
            os.chdir(baseprojectdir+'/'+envdir+'/'+tierlist[tier])
            # 00beconf2.tfvars unique in each env tier component directory
            with open("00beconf2.tfvars", "a") as w:
                w.write("container_name =\"%s-%s\"" % (azprojectname, tierlist[tier]))
                w.close()
            for i in reversed(range(len(realtfvars))):
                os.symlink('../'+realtfvars[i], realtfvars[i])
            if str(tierlist[tier]) != 'bootstrap':
                print('')
                print('Creating symlink in %s to root variables.tf...' % (tierlist[tier]))
                #os.symlink('../../variables.tf', 'variables.tf')
                symlinkcmd = ('ln -s ../../variables.tf .')
                symlinkcmdraw = run(symlinkcmd, hide=True, warn=True)
        print('')
        print('Setting variables.tf symlink in appropriate component modules locations...')
        for tier in range(len(tierlist)):
            if str(tierlist[tier]) != 'bootstrap':
                print('Creating symlink in module %s to root variables.tf...' % (tierlist[tier]))
                os.chdir(baseprojectdir+'/modules/'+tierlist[tier])
                #os.symlink('../../variables.tf', 'variables.tf')
                symlinkcmd = ('ln -s ../../variables.tf .')
                symlinkcmdraw = run(symlinkcmd, hide=True, warn=True)
                extravars = glob.glob('variables-*.tf')
                if len(extravars) != 0:
                    print('%s module specific variables-*.tf found, creating symlink in related %s location...' % (tierlist[tier],envdir))
                    for varfile in range(len(extravars)):
                        os.chdir(baseprojectdir+'/'+envdir+'/'+tierlist[tier])
                        symlinkcmd = ('ln -s ../../modules/%s/%s .' % (tierlist[tier],extravars[varfile]))
                        symlinkcmdraw = run(symlinkcmd, hide=True, warn=True)
        os.chdir(baseprojectdir+'/'+envdir)
        print('')
        print('Next, we will create or select an existing resource group where the base')
        print('VM images will be located. It is recommended that this be a separate resource')
        print('group from any OpenShift resource groups and should be considered as a')
        print('\"long-life\" resouce group, as it will be advantageous to utilize for other')
        print('deployments in an ongoing manner. NOTE that it should have the same Azure')
        print('location as any OpenShift resource groups that it provides base RHEL VM images')
        print('to.')
        vmrg, vmrgloc = createresourcegroup(ctx)
        print('')
        print('Now create a storage account where base RHEL VM images will be stored. These')
        print('VM images can then be utilized during OpenShift cluster deployment.')
        stac4vm = createstorageaccount(ctx, resourcegroup=vmrg, location=vmrgloc)
        stcntr4vm = createstoragecontainer(ctx, stacname=stac4vm, stcontname='images')
        # 01base.tfvars in env-<dev/qa/prod> root
        sublocs = ['azureserviceprincipalid',
                'azureserviceprincipalsecret',
                'azuretenantid',
                'azuresubscriptionid',
                'ocpresourcegroupname',
                'southcentralus',
                'projectname',
                'vmimageresourcegroupname']
        provided = [aad_client_id,
                    aad_client_secret,
                    tenant_id,
                    subscription_id,
                    rg2use,
                    loc2use,
                    azprojectname,
                    vmrg]
        subdict = dict(zip(sublocs, provided))
        findnreplace(baseprojectdir+'/'+envdir+'/01base.tfvars', subdict)
        print('')
        print('Finally, if desired, we will create a SSH key pair to use for accessing')
        print('our OpenShift cluster.')
        sshproceed = confirm(prompt='Would you like to create a SSH key pair at this time?')
        if sshproceed == True:
            sshbaseprefix = sshgenkeypair(ctx)
            sublocs = ['openshift_id.pub',
            'openshift_id.forJSON']
            provided = [sshbaseprefix+'_ecdsa-sha2-nistp521.pub',
                        sshbaseprefix+'_ecdsa-sha2-nistp521.forJSON']
            subdict = dict(zip(sublocs, provided))
            findnreplace(baseprojectdir+'/'+envdir+'/02ocp.tfvars', subdict)
        else:
            print('You have elected not to create a SSH key pair.  You will need to')
            print('create and place a SSH public and private key pair in the ssh directory')
            print('located in the appropriate env-<qa/dev/prod> environment directory')
            print('and then edit the following entries in the 02ocp.tfvars file located')
            print('in the root of the environment directory:')
            print(' - ssh_public_key_path')
            print(' - connection_private_ssh_key_path')
            print('Note that the connection_private_ssh_key_path entry must point to a')
            print('"JSON-readied" version of the private key.')
            print('Use the following command to accomplish this with your supplied private')
            print('key file:')
            print('sed \':a;N;$!ba;s/\\n/\\\\n/g\' private_key_file_name > private_key_file_name.forJSON')
        print('')
        print('Now proceed to make appropriate value entries in the following variables')
        print('files, located relative to the base env-<qa/dev/prod> environment directory:')
        for i in reversed(range(len(sampletfvar))):
            print(' --> %s' % (os.path.splitext(sampletfvar[i])[0]))

@task
def sshgenkeypair(ctx):
    """create ECDSA public/private key pair"""
    rootDir=os.getcwd()
    os.chdir(rootDir+'/ssh')
    basekeyname = input("Please enter a base prefix to use for a newly generated SSH key pair > ")
    keycomment = input("Please enter a comment for the public key, format like 'username@domain.com' recommended > ")
    genkeypair = run(('ssh-keygen -t ecdsa -b 521 -C %s -f %s_ecdsa-sha2-nistp521 -N \'\'') % (keycomment, basekeyname), hide=True, warn=True)
    print('Adding JSON compatible version of private key...')
    keyfile = os.getcwd()+'/%s_ecdsa-sha2-nistp521' % basekeyname
    keyfile4json = os.getcwd()+'/%s_ecdsa-sha2-nistp521.forJSON' % basekeyname
    shutil.copy(keyfile,keyfile4json)
    # Note: this sed command does the same thing, would have to add escapes for python run command: sed ':a;N;s/\n/\\n/;ta'
    sed4json = run(('cat "%s" | sed \':a;N;$!ba;s/\\n/\\\\n/g\' > "%s"') % (keyfile, keyfile4json), hide=True, warn=True)
    str(sed4json).strip()
    print('SSH key pair generation complete.')
    os.chdir(rootDir)
    return basekeyname

@task
def vmimageupload(ctx):
    """upload VM image to Azure"""
    print('Upload one of the following VM images to Azure:')
    baseprojectdir, envdir = os.path.split(os.getcwd())
    packerdir = baseprojectdir+'/packer-rhel7'
    packermanifest = packerdir+'/manifest.json'
    with open(packermanifest, 'r') as handle:
        packerjson = json.load(handle)
    handle.close()
    buildlist = packerjson['builds']
    imagelist = []
    for i in range(len(buildlist)):
        for j in (buildlist[i]['files']):
            print("%-3s %-50s" % (i, os.path.splitext(j['name'])[0]+'.vhd'))
            imagelist.append(os.path.splitext(j['name'])[0]+'.vhd')
    imageint = ''
    while imageint not in (range(len(imagelist))):
        imageindex = input("Please select desired VM image# 0-%s  > " % (len(imagelist) - 1))
        try:
            imageint = int(imageindex)
        except ValueError:
            imageindex  = ''
    print("%s" % (imagelist[imageint]))
    return 

@task
def createresourcegroup(ctx):
    """create Azure resource group"""
    while True:
        azrgname = input("Please enter desired resource group name > ")
        ansrStr = str(confirm(prompt='You entered "'+azrgname+'" as the desired resource group name. Is this correct?'))
        if ansrStr == 'True':
            azrgstate = run(('az group show -n %s | jq \'.properties.provisioningState\' | tr -d \'"\'') % (azrgname), hide=True, warn=True)
            if str(azrgstate.stdout).strip() == 'Succeeded':
                ansrStr = str(confirm(prompt='Resource group "'+azrgname+'" already exists, are you sure you want to use this resource group?'))
                if ansrStr == 'True':
                    print('Use existing resouce group')
                    spinner = Spinner()
                    spinner.start()
                    rglocation = run(('az group show -n %s | jq \'.location\' | tr -d \'"\'') % (azrgname), hide=True, warn=True)
                    spinner.stop()
                    rglocation = rglocation.stdout.strip()
                    return (azrgname, rglocation)
                else:
                    continue
            else:
                print(str(azrgstate.stdout))
                rglocation = selectlocation(ctx)
                ansrStr = str(confirm(prompt='Creating resource group "'+azrgname+'" in location "'+rglocation+'". Is this correct?'))
                if ansrStr == 'True':
                    spinner = Spinner()
                    spinner.start()
                    azrgcreate = run(('az group create -l %s -n %s') % (rglocation, azrgname), hide=True, warn=True)
                    spinner.stop()
                    azrgcreateio = StringIO(azrgcreate.stdout.strip())
                    azrgcreatejson = json.load(azrgcreateio)
                    if azrgcreatejson['properties']['provisioningState'] == 'Succeeded':
                        print('Creation of resource group "%s" in "%s" succeeded.' % (azrgname, rglocation))
                        return (azrgname, rglocation)
                    else:
                        print('An error occured')
                        print(azrgcreate.stderr.strip())
                        return False
                else:
                    continue
        else:
            print('Try again')
            continue

@task
def listresourcegroups(ctx):
    """list current Azure resource groups"""
    del ctx
    azgrplistcmd = 'az group list'
    spinner = Spinner()
    spinner.start()
    azgrplistraw = run(azgrplistcmd, hide=True, warn=True)
    spinner.stop()
    azgrplistio = StringIO(azgrplistraw.stdout)
    azgrplistjson = json.load(azgrplistio)
    for i in range(len(azgrplistjson)):
        print(azgrplistjson[i]['name'])

@task
def selectlocation(ctx):
    """select an existing Azure resource group"""
    del ctx
    azlocationlistcmd = 'az account list-locations'
    spinner = Spinner()
    spinner.start()
    azlocationlistraw = run(azlocationlistcmd, hide=True, warn=True)
    spinner.stop()
    azlocationlistio = StringIO(azlocationlistraw.stdout)
    azlocationlistjson = json.load(azlocationlistio)
    print("Available locations\n")
    print("%-3s %-25s %-25s" % ("ID", "Name", "Description"))
    print("%-3s %-25s %-25s" % ("--", "--------------------", "-------------------------"))

    for i in range(len(azlocationlistjson)):
        print("%-3s %-25s %-25s" % (i, azlocationlistjson[i]['displayName'], azlocationlistjson[i]['name']))
    locationint = ''
    while locationint not in range(len(azlocationlistjson)):
        locationindex = input("Please select desired Azure location ID# 0-%s  > " % (len(azlocationlistjson) - 1))
        try:
            locationint = int(locationindex)
        except ValueError:
            locationindex = ''

    print("%s" % (azlocationlistjson[locationint]['name']))
    return azlocationlistjson[locationint]['name']

@task
def createstorageaccount(ctx, resourcegroup='', location='', stacname=''):
    """create Azure storage account"""
    while azureloggedin():
        if resourcegroup == '':
            rg2use, loc2use = createresourcegroup(ctx)
        else:
            rg2use = resourcegroup
            loc2use = location
        while stacname == '':
            stacname = input("Please enter desired storage account name > ")
            ansrStr = str(confirm(prompt='You entered "'+stacname+'" as the desired storage account name. Is this correct?'))
            if ansrStr == 'True':
                print('Creating storage account "'+stacname+'"...')                        
            else:
                print('Try again')
                stacname = ''
                continue
        spinner = Spinner()
        spinner.start()
        azstaccreate = run(('az storage account create --location \'%s\' --name %s --resource-group %s --sku Standard_LRS --kind StorageV2') % (loc2use, stacname, rg2use), hide=True, warn=True)
        spinner.stop()
        azstaccreateio = StringIO(azstaccreate.stdout)
        azstaccreatejson = json.load(azstaccreateio)
        # alternate method if needed...doesn't handle stdout/stderr as easily
        #azstaccreate = cmdline(("az storage account create --location \'%s\' --name %s --resource-group %s --sku Standard_LRS") % (loc2use, stacname, rg2use))
        #azstaccreatejson = json.loads(azstaccreate.decode("utf-8"))
        if azstaccreatejson['provisioningState'] == 'Succeeded':
            print('Creation of storage account "%s" in resource group "%s" succeeded.' % (stacname, rg2use))
            return (stacname)
        else:
            print('An error occured')
            print(azstaccreate.stderr.strip())
            return False

@task
def createstoragecontainer(ctx, stacname='', stcontname=''):
    """create Azure storage container in storage account"""
    while azureloggedin():
        while stcontname == '':
            while True:
                stacname = input("Please enter storage account where the storage container will reside > ")
                ansrStr = str(confirm(prompt='You entered "'+stacname+'" as the storage account for the new storage container. Is this correct?'))
                if ansrStr == 'True':
                    spinner = Spinner()
                    spinner.start()
                    storacctcmd = run('az storage account list | jq \'.[].name\' | tr -d \'"\'', hide=True, warn=True)                    
                    spinner.stop()
                    storacctlist = (storacctcmd.stdout).splitlines()
                    if stacname not in storacctlist:
                        ansrStr = str(confirm(prompt='Storage account "'+stacname+'" does not currently exist. Would you like to create?'))
                        if ansrStr == 'True':
                            newstacname = stacname
                            createstorageaccount(ctx, stacname=newstacname)
                            break
                        else:
                            print('Storage account required for storage container. Exiting...')
                            return False
                    else:
                        print('Using existing storage account "%s"' % (stacname))
                        break
                else:
                    continue
            while True:
                stcontname = input("Please enter desired storage container name > ")
                ansrStr = str(confirm(prompt='You entered "'+stcontname+'" as the desired storage container name. Is this correct?'))
                if ansrStr == 'True':
                    break                        
                else:
                    continue
        spinner = Spinner()
        spinner.start()
        storcntrcreate = run(('az storage container create --account-name %s --name %s') % (stacname, stcontname), hide=True, warn=True)
        spinner.stop()
        try:
            storcntrcreatejson = json.load(StringIO(storcntrcreate.stdout))
        except ValueError:
            errmsg = storcntrcreate.stderr.strip()
            errmsglist = errmsg.splitlines()
            for i in range(len(errmsglist)):
                if "ERROR" in errmsglist[i]:
                    print(errmsglist[i])
            return False
        if storcntrcreatejson['created'] == True:
            print('Creation of storage container "%s" in storage account "%s" succeeded.' % (stcontname, stacname))
            return (stcontname)
        else:
            print('Creation of storage container "%s" failed.' % (stcontname))
            print(storcntrcreate.stdout.strip())
            return False


@task
def crsterraformupdate(ctx):
    """copy bootstrap generated crsapp-main.tf and crsreg-main.tf to individual module locations"""
    print("copy ./bootstrap/output/crsapp-main.tf to ../modules/crsapp/main.tf")
    crsappcmd = ('cp ./bootstrap/output/crsapp-main.tf ../modules/crsapp/main.tf')
    crsappcmdraw = run(crsappcmd, hide=False, warn=True)
    print("copy ./bootstrap/output/crsreg-main.tf to ../modules/crsreg/main.tf")
    crsregistrycmd = ('cp ./bootstrap/output/crsreg-main.tf ../modules/crsreg/main.tf')
    crsregistrycmdraw = run(crsregistrycmd, hide=False, warn=True)

@task
def tfinit(ctx, component, beconf=''):
    """initialize given terraform component tier"""
    print("component=%s" % (component))
    beconf = beconf.split(",")
    for i in range(len(beconf)):
        beconf[i] = os.getcwd()+'/'+component+'/'+beconf[i]
        beconf[i] = beconf[i].replace('"', '')
    tf_dir = os.getcwd()+'/'+component
    tf = Terraform(working_dir=tf_dir)
    tfinitout = tf.init(no_color=IsNotFlagged, capture_output=False, backend_config=beconf)

@task
def tfplan(ctx, component, planout='', varfile=''):
    """create deploy planfile for specified terraform component deployment"""
    tf_dir = os.getcwd()+'/'+component
    varfile = varfile.split(",")
    for i in range(len(varfile)):
        varfile[i] = tf_dir+'/'+varfile[i]
        varfile[i] = varfile[i].replace('"', '')
    #If any local*.tfvars files are present for local variable overrides, add them to var-file list
    print('NOTE: any local*.tfvars files that are present for local variable overrides will be appended to plan var-file list')
    localtfvar = glob.glob(tf_dir+'/'+'local*.tfvars')
    for i in range(len(localtfvar)):
        print('Appending %s to var-file list...' % (localtfvar[i]))
        varfile.append(localtfvar[i])
    tf = Terraform(working_dir=tf_dir)
    tfplanout = tf.plan(no_color=IsNotFlagged, capture_output=False, out=planout, var_file=varfile)

@task
def tfrefresh(ctx, component, varfile=''):
    """refresh state for specified terraform component deployment"""
    tf_dir = os.getcwd()+'/'+component
    varfile = varfile.split(",")
    for i in range(len(varfile)):
        varfile[i] = tf_dir+'/'+varfile[i]
        varfile[i] = varfile[i].replace('"', '')
    #If any local*.tfvars files are present for local variable overrides, add them to var-file list
    print('NOTE: any local*.tfvars files that are present for local variable overrides will be appended to plan var-file list')
    localtfvar = glob.glob(tf_dir+'/'+'local*.tfvars')
    for i in range(len(localtfvar)):
        print('Appending %s to var-file list...' % (localtfvar[i]))
        varfile.append(localtfvar[i])
    tf = Terraform(working_dir=tf_dir)
    tfplanout = tf.cmd(no_color=IsNotFlagged, capture_output=False, cmd='refresh', var_file=varfile)

@task
def tfdestroyplan(ctx, component, planout='', varfile=''):
    """create destroy planfile for specified terraform component deployment"""
    tf_dir = os.getcwd()+'/'+component
    varfile = varfile.split(",")
    for i in range(len(varfile)):
        varfile[i] = tf_dir+'/'+varfile[i]
        varfile[i] = varfile[i].replace('"', '')
    #If any local*.tfvars files are present for local variable overrides, add them to var-file list
    localtfvar = glob.glob(tf_dir+'/'+'local*.tfvars')
    for i in range(len(localtfvar)):
        varfile.append(localtfvar[i])
    tf = Terraform(working_dir=tf_dir)
    tfplanout = tf.plan(no_color=IsNotFlagged, capture_output=False, out=planout, var_file=varfile, destroy=IsFlagged)

@task
def tfapply(ctx, component, dir_or_plan=''):
    """apply planfile against specified terraform component tier"""
    print("planfile=%s" % (dir_or_plan))
    tf_dir = os.getcwd()+'/'+component
    if dir_or_plan == 'latest':
        #Code to select the most recently created planfile
        applyplan = 'latest'
    else:
        os.chdir(tf_dir)
        pflist = glob.glob('*.tfplan')
        pflist.reverse()
        print("Available plan files\n")
        print("%-3s %-25s" % ("ID", "Plan"))
        print("%-3s %-25s" % ("--", "--------------------"))

        for i in range(len(pflist)):
            print("%-3s %-25s" % (i, pflist[i]))
        planfileint = ''
        while planfileint not in range(len(pflist)):
            planfileindex = input("Please select desired Terraform plan file ID# 0-%s  > " % (len(pflist) - 1))
            try:
                planfileint = int(planfileindex)
            except ValueError:
                planfileindex = ''
        applyplan = pflist[planfileint]
        print("Selected plan file %s" % (applyplan))
        applyplan = tf_dir+'/'+applyplan

    tf = Terraform(working_dir=tf_dir)
    tfapplyout = tf.apply(no_color=IsNotFlagged, capture_output=False, dir_or_plan=applyplan)


@task
def tfshow(ctx, component):
    """show current state of given terraform component tier"""
    tf_dir = os.getcwd()+'/'+component
    tf = Terraform(working_dir=tf_dir)
    tfshowout = tf.show(no_color=IsFlagged, capture_output=True)
    print("'{0}'".format(tfshowout[1]))

@task
def tfoutput(ctx, component):
    """list outputs from provided terraform component deployment"""
    tf_dir = os.getcwd()+'/'+component
    tf = Terraform(working_dir=tf_dir)
    tfoutputout = tf.output(no_color=IsFlagged, capture_output=True)
    tfoutputout = json.dumps(tfoutputout)
    tfoutputjson = json.loads(tfoutputout)
    for k, v in tfoutputjson.items():
        print('{0} = {1}'.format(k, v['value']))

@task
def tfdestroy(ctx, component, varfile=''):
    """destroy specified terraform component deployment"""
    print('*** WARNING *** This will execute immediate destruction of the %s tier without plan announcement!!!' % (component))
    print('*** WARNING *** Recommended destroy method is to first generate destroy plan via')
    print('*** WARNING *** \'tf destroyplan\' <tier> followed by \'tf apply\' <tier> and select generated destroy plan.')
    ansr = confirm(prompt='Are you sure you wish to destroy terraform component tier "'+component+'"?')
    ansrStr = str(ansr)
    if ansrStr == 'True':
        print('Proceeding with terraform destroy for %s' % (component))
        tf_dir = os.getcwd()+'/'+component
        varfile = varfile.split(",")
        for i in range(len(varfile)):
            varfile[i] = tf_dir+'/'+varfile[i]
            varfile[i] = varfile[i].replace('"', '')
        #If any local*.tfvars files are present for local variable overrides, add them to var-file list
        localtfvar = glob.glob(tf_dir+'/'+'local*.tfvars')
        for i in range(len(localtfvar)):
            varfile.append(localtfvar[i])
        tf = Terraform(working_dir=tf_dir)
        tfdestroyout = tf.destroy(no_color=IsNotFlagged, capture_output=False, var_file=varfile)
    else:
        print('Exiting from destruction of %s' % (component))
