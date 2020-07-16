#!/bin/bash -e
set -e

if [ $# -lt 3 ]; then
  echo "there is no sufficient argument(s) passed"
  echo ""
  echo "Example command"
  echo "$0 bcm http://artifacts/url/path ./downloads/directory"
  echo "$0 lgi nil ./downloads/directory"
  exit
fi

# input alignments
#WSPACE=$PWD/workspace-brcm
_3PIPS_PROVIDER=$1
DL_URL=$2
DL_PATH=$3
DLDIR=downloads

#mkdir -p $WSPACE
#cd $WSPACE

#######################################
# setup artifacts
mkdir -p $DL_PATH

download_list=(
"refsw_release_unified_URSR_19.2.1_20200201.tgz"
"stblinux-4.9-1.15.tar.bz2"
"refsw_release_unified_URSR_19.2.1_20200201_3pips_libertyglobal.tgz"
"refsw_release_unified_URSR_19.2.1_20200201_3pip_broadcom.tgz"
"applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz"
)

# TODO: we should change how to download from Artifacts server
function download_file () {
    local from="$DL_URL"
    local to="$DL_PATH"
    echo "downloading $(basename $from) file..."
    if [[ ${from} == s3://* ]]; then
	aws s3 cp "${from}" "${to}"
    else
	rsync -aP "${from}" "${to}"
    fi
}

mkdir -p $DLDIR

for i in ${download_list[@]}; do
  # download file if not available
  if [ $DL_URL != nil -a ! -f $DL_PATH/$i ]; then
      download_file "$DL_URL/$i" "$DL_PATH"
  fi

  if [ $i == *3pips_libertyglobal* -a $_3PIPS_PROVIDER == bcm ]; then
      continue
  elif [ $i == *3pip_broadcom* -a $_3PIPS_PROVIDER == lgi ]; then
      continue
  fi

  if [[ $i == *3pip* ]]; then
    artifact=refsw_release_unified_URSR_19.2.1_20200201_3pip_broadcom.tgz
    dest=$DLDIR/$artifact
    ln -sf $DL_PATH/$i $dest
  else
    dest=$DLDIR/$i
    ln -sf $DL_PATH/$i $dest
  fi
  touch $dest.done
done
exit
#########################################
# RDK workspace setup
if [ ! -d meta-cmf ]; then
repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next.xml
fi
repo sync -j `nproc` --no-tags --no-clone-bundle

# additional setup
mkdir -p rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt


#########################################
##### cherry picks
## RDKCMF-8631 Fix aamp not playing video on RPI
(cd rdk/components/generic/aamp; git fetch "https://code.rdkcentral.com/r/rdk/components/generic/aamp" refs/changes/39/40439/1 && git cherry-pick FETCH_HEAD)
## RDKCMF-8631 Add ocdm and playready packageconfigs for aamp
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/94/40594/1 && git cherry-pick FETCH_HEAD)
## RDKCMF-8640 Enable gold linker as default
(cd meta-rdk; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk" refs/changes/87/38887/2 && git cherry-pick FETCH_HEAD)

#########################################
tempscript=_build.sh
rm -rf $tempscript

cat <<EOF > $tempscript
######### brcm972180hbc build
declare -x MACHINE="brcm972180hbc-refboard"
declare -x RDK_ENABLE_64BIT="n"
declare -x RDK_ENABLE_AMAZON="n"
declare -x RDK_ENABLE_BAS="n"
declare -x RDK_ENABLE_BT_BLUEZ="n"
declare -x RDK_ENABLE_BT_FLUORIDE="n"
declare -x RDK_ENABLE_COBALT="n"
declare -x RDK_ENABLE_DEBUG_BUILD="y"
declare -x RDK_ENABLE_DTCP="n"
declare -x RDK_ENABLE_DTCP_SAGE="n"
declare -x RDK_ENABLE_NEXUS_USER_MODE="n"
declare -x RDK_ENABLE_SSTATE_MIRRORS_MODE="n"
declare -x RDK_ENABLE_SVP="y"
declare -x RDK_FETCH_FROM_DMZ="n"
declare -x RDK_URSR_VERSION="19.2.1"
declare -x RDK_7218_VERSION="B0"
declare -x RDK_USING_WESTEROS="y"
declare -x RDK_WITH_RESTRICTED_COMPONENTS="n"
declare -x RDK_ENABLE_WPE_METROLOGICAL="y"
declare -x RDK_WITH_OPENCDM="y"
declare -x RDK_ENABLE_REFERENCE_IMAGE="y"

declare -x REFSW_3PIP_MD5=“58738053e35695ff07c09a781f80c345”
declare -x REFSW_3PIP_SHA256=“b7e8e0bea25b133c37956a8412e03121fdb6aabe374201216bc2c47c2707b386"

source  ./meta-rdk-broadcom-generic-rdk/setup-environment-refboard-rdkv
EOF

echo ""
echo "RUN FOLLOWING command TO BUILD: "
echo "source $tempscript ; bitbake rdk-generic-reference-image"
