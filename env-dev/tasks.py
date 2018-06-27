import os
import sys
import json
import glob
import logging
import tempfile
import re, shutil, tempfile
from invoke import run
from invoke import task
from io import StringIO
from python_terraform import *

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

def azurelogin():
    credsjson = 'azcreds.json'
    with open(credsjson, 'r') as handle:
        config = json.load(handle)
    azlogin = run(('az login --service-principal --username %s --password %s --tenant %s') % (config["aad_client_id"], config["aad_client_secret"], config["tenant_id"]), hide=True, warn=True)
    azloginio = StringIO(azlogin.stdout.strip())
    azloginjson = json.load(azloginio)[0]
    if azloginjson['state'] == 'Enabled':
        print('Azure login via service principal "%s" succeeded.' % (config["aad_client_id"]))
        return (config["aad_client_id"], config["aad_client_secret"], config["tenant_id"])
    else:
        print('Service principal login unsuccessful, please ensure credentials in azcreds.json are correct.')
        print(azlogin.stderr.strip())
        return False

def clear():
    _ = os.system('clear')

@task
def envinit(ctx):
    """intial environment preparation"""
    print('Logging into Azure using credentials provided via azcreds.json...')
    aad_client_id, aad_client_secret, tenant_id = azurelogin()
    if aad_client_id != "False":
        print('Performing initial environment preparation steps...')
        print('Copying sample tfvars into place...')
        rootDir=os.getcwd()
        baseprojectdir, envdir = os.path.split(os.getcwd())
        sampletfvar = glob.glob('0*.sample')
        for i in reversed(range(len(sampletfvar))):
            print('Copying %s to %s' % (sampletfvar[i],os.path.splitext(sampletfvar[i])[0]))
            shutil.copy(sampletfvar[i],os.path.splitext(sampletfvar[i])[0])
        realtfvars = glob.glob('*.tfvars')
        tierlist = [ 'bastion', 'bootstrap', 'crsapp', 'crsreg', 'infra', 'master', 'network', 'network-crs', 'node', 'openvpn']
        print('Setting tfvars file symlinks to appropriate %s tier component locations...' % envdir)
        for tier in range(len(tierlist)):
            print('Creating tfvars symlinks in %s...' % (tierlist[tier]))
            os.chdir(baseprojectdir+'/'+envdir+'/'+tierlist[tier])
            for i in reversed(range(len(realtfvars))):
                os.symlink('../'+realtfvars[i], realtfvars[i])
            if str(tierlist[tier]) != 'bootstrap':
                print('Creating symlink in %s to root variables.tf...' % (tierlist[tier]))
                #os.symlink('../../variables.tf', 'variables.tf')
                symlinkcmd = ('ln -s ../../variables.tf .')
                symlinkcmdraw = run(symlinkcmd, hide=True, warn=True)
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
        rg2use, loc2use = createresourcegroup(ctx)
        sublocs = ['azureserviceprincipalid',
                'azureserviceprincipalsecret',
                'azuretenantid',
                'ocpresourcegroupname',
                'southcentralus']
        provided = [aad_client_id,
                    aad_client_secret,
                    tenant_id,
                    rg2use,
                    loc2use]
        subdict = dict(zip(sublocs, provided))
        findnreplace('01base.tfvars', subdict)
    else:
        print('An error occured logging into Azure, correct the issue and try again.')
        exit

@task
def sshgenkeypair(ctx):
    """create ECDSA public/private key pair"""
    basekeyname = input("Please enter a base filename to use for a newly generated SSH key pair > ")
    keycomment = input("Please enter a comment for the public key, format like 'username@domain.com' recommended > ")
    genkeypair = run(('ssh-keygen -t ecdsa -b 521 -C %s -f %s_ecdsa-sha2-nistp521 -N \'\'') % (keycomment, basekeyname), hide=True, warn=True)
    print('Adding JSON compatible version of private key...')
    rootDir=os.getcwd()
    keyfile = os.getcwd()+'/%s_ecdsa-sha2-nistp521' % basekeyname
    keyfile4json = os.getcwd()+'/%s_ecdsa-sha2-nistp521.forJSON' % basekeyname
    shutil.copy(keyfile,keyfile4json)
    sed4json = run(('cat "%s" | sed \':a;N;$!ba;s/\\n/\\\\n/g\' > "%s"') % (keyfile, keyfile4json), hide=True, warn=True)
    str(sed4json).strip()
    print('SSH key pair generation complete.')

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
                    rglocation = run(('az group show -n %s | jq \'.location\' | tr -d \'"\'') % (azrgname), hide=True, warn=True)
                    return (azrgname, rglocation)
                else:
                    continue
            else:
                print(str(azrgstate.stdout))
                rglocation = selectlocation(ctx)
                ansrStr = str(confirm(prompt='Creating resource group "'+azrgname+'" in location "'+rglocation+'". Is this correct?'))
                if ansrStr == 'True':
                    azrgcreate = run(('az group create -l %s -n %s') % (rglocation, azrgname), hide=True, warn=True)
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
    azgrplistraw = run(azgrplistcmd, hide=True, warn=True)
    azgrplistio = StringIO(azgrplistraw.stdout)
    azgrplistjson = json.load(azgrplistio)
    for i in range(len(azgrplistjson)):
        print(azgrplistjson[i]['name'])

@task
def selectlocation(ctx):
    """select an existing Azure resource group"""
    del ctx
    azlocationlistcmd = 'az account list-locations'
    azlocationlistraw = run(azlocationlistcmd, hide=True, warn=True)
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
def createstorageaccount(ctx, resourcegroup, location, saname):
    """create Azure storage account for tfstate"""
    azsacreatecmd = ('az storage account create --location \'%s\' --name %s --resource-group %s --sku Standard_LRS') % (location, resourcegroup, saname)
    azsacreateraw = run(azsacreatecmd, hide=True, warn=True)
    azsacreateio = StringIO(azsacreateraw.stdout)
    azsacreatejson = json.load(azsacreateio)

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
