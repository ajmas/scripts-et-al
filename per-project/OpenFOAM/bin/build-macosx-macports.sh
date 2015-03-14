#!/bin/bash

## All in one Build Script for OpenFOAM on MacOS X 
## ===============================================
##
## Intro
## -----
## 
## This is script is designed to make life easier, for building OpenFOAM
## on MacOS X. While many people are quite happy following a set of written
## instructions, there are others who just want things to work - it could be
## a question of laziness, but probably more that people want to focus on 
## what they are good at instead of learning something they feel they shouldn't
## need to.
##
## This script also makes it easier to eventually set up an automated build
## environment, though there may be some tweaks needed.
##
## Requirements
## ------------
##
##   - MacPorts
##   - XCode
##
## More Detail
## -----------
##
## This script does the following
##    - Creates & mounts the case-sensitive HFS+ Disk image
##    - Install the necessary ports from MacPorts
##    - Checks to see that necessary environment dependencies are in place
##    - Clones the Git project
##    - Builds the source code

git_repo="https://github.com/ajmas/OpenFOAM-2.3.x.git"
git_repo_local="OpenFOAM-2.3.x"
git_branch="macosx-forum-patched"
vol_name="OpenFOAM-Development-2.3.x"
image_name="${vol_name}.dmg"
mount_path="/Volumes/${vol_name}"
gcc_cmd=gcc48
log_file=build.log

#############################################

# From: http://stackoverflow.com/questions/407523
# Deals with escaping the parameters automatically
function sedeasy {
  sed -i ".bak" "s/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3
}

echo "MacOS X version is ..... $(sw_vers -productVersion)"

# We need a case-sensitive file system to do our work on
if [[ ! -f "openfoam-development-2.3.x.dmg" ]]; then
    echo "Creating cases-sensitive FS, in a disk image"
    hdiutil create -size 3g -fs "Case-sensitive Journaled HFS+" -volname "${vol_name}"  ${image_name}
    if [ $? -ne 0 ]; then
        echo "hditutil exited with non-zero exit code. Please resolve issue before continuing."
        exit 1
    fi 
fi

if [[ ! -d "${mount_path}" ]]; then
    echo "Mounting disk image at '${mount_path}'"
    hdiutil mount ${image_name}
    if [ $? -ne 0 ]; then
        echo "hditutil exited with non-zero exit code. Please resolve issue before continuing."
        exit 1
    fi     
else
    echo "Disk image already mounted at '${mount_path}'"
fi

cd "/Volumes/${vol_name}"

# If we have detected MacPorts try installing everything we need. At this point
# this code is not smart enough to limit to missing ports
if [[ -x "/opt/local/bin/port" ]]; then
    echo "Detected MacPorts, will use this to install neccesary ports"
    echo "You may need to authenticate multiple times, if the sudo window expires"
    
    sudo port selfupdate

    sudo port install ${gcc_cmd} \    
    openmpi-${gcc_cmd} \
    boost +openmpi \
    cgal ccache flex \
    scotch -mpich +${gcc_cmd} +openmpi \
    metis +${gcc_cmd}
    
    if [ $? -ne 0 ]; then
        echo "port exited with non-zero exit code. Please resolve issue before continuing."
        exit 1
    fi     
    
    sudo port select --set gcc mp-${gcc_cmd}
    sudo port select --set mpi openmpi-${gcc_cmd}-fortran

    sudo port select --summary
    
    # We need to ensure that MacPorts is first on the path, otherwise we
    # run into behaviour issues when non-MacPorts versions of the binaries
    # are used, such as with flex. 
    export PATH=/opt/local/bin:$PATH
    
else
    echo "This script only supports MacPorts as this point, so you are on your own until"
    echo "this script is updated. If you are using another package manager, "
    echo "please consider contributing changes to this script. Will blindly continue..."
fi

if [[ ! -d "/Applications/paraview.app" ]]; then
    echo "Paraview is not installed. You can install it from http://www.paraview.org/"
    exit 1
fi

if [[ ! -d "${git_repo_local}" ]]; then
    git clone "${git_repo}" "${git_repo_local}"
fi

cd "${git_repo_local}"

if [[ `git config core.ignorecase` != "false" ]]; then
    echo "Git was not set to not ignore case, fixing things up..."
    git config core.ignorecase false
    git reset --hard
fi

git checkout master

# TODO pull, auto cleanup, stashing, etc

# Create a link to paraview
if [[ ! -d "/Applications/paraview.app" ]]; then
    cd bin
    ln -s /Applications/paraview.app/Contents/MacOS/paraview
    cd ..
fi

# Observations: simply select gcc to use mp-gcc46 (or which ever gcc version you are using)
# is not enough to resolve the  error "MPICH wants the same version as the used compiler",
# hence needing to modify the bashrc file

# Do the substitution in the etc/bashrc file to avoid a manual step

echo "Updating the bashrc as appropriate, for foamInstall & WM_COMPILER"

gcc_cmd=`echo ${foo:0:1} | tr  '[a-z]' '[A-Z]'`${gcc_cmd:1}

sedeasy "^foamInstall=.*" "foamInstall=${mount_path}" etc/bashrc
sedeasy "^export WM_COMPILER=.*" "export WM_COMPILER=${gcc_cmd}" etc/bashrc

echo
echo
echo "Loading OpenFOAM bashrc"

. ./etc/bashrc

if [ $? -ne 0 ]; then
    echo "bashrc exited with non-zero exit code. Please resolve issue before continuing."
    exit 1
fi      

echo
echo
echo "If we got here without errors, let's get this build started... (This will talke a long while)"
echo

echo "First we do a clean, to ensure previous artifacts don't cause issues"

./wmake/wcleanAll 2>&1 | tee "${git_repo_local}/${log_file}"

echo "Now doing the build"

./Allwmake 2>&1 | tee "${git_repo_local}/${log_file}"

if [ $? -ne 0 ]; then
    echo
    echo "The build failed. You should look at the build log at '${git_repo_local}/${log_file}' see what went wrong"
    exit 1
fi     






