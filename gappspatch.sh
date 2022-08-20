#!/bin/sh

#isoファイルの名前を作成

timedate=`date '+%Y%m%d%H%M%S'`

#引数が指定されているか確認
if [ $# != 1 ]; then
  echo "isoファイルが指定されていません"
  echo "例:bash gappspatch.sh android11.iso"
  exit 1
fi

#指定したisoファイルが存在するかチェック
if [ -f $1 ]; then
  echo ""
else
  echo "指定したファイル名が存在しません"
  echo "例:bash gappspatch.sh android11.iso"
  exit 1
fi

#実行に必要なパッケージをチェック

installpkg="squashfs-tools unzip genisoimage wget"

which wget > /dev/null 2>&1 && which unzip > /dev/null 2>&1 && which mkisofs > /dev/null 2>&1 && which mksquashfs > /dev/null 2>&1
if [ $? -ne 0 ] ; then
  sudo apt update
  sudo apt install -y $installpkg
fi


echo $timedate".iso を作成します"
mkdir out
sudo mkdir /mnt/isoout
sudo mkdir /mnt/system
sudo mount -t iso9660 -o loop $1 /mnt/isoout
#Android x86のisoなのか確認
if [ -f /mnt/isoout/system.sfs ]; then
  echo ""
else
  sudo umount -R /mnt/isoout
  rm -r out
  sudo rm -r /mnt/isoout
  sudo rm -r /mnt/system
  echo "対応しているAndroid x86のisoイメージではありません"
  echo "例:bash gappspatch.sh android11.iso"
  exit 1
fi

sudo cp -r /mnt/isoout out/
sudo umount -R /mnt/isoout
sudo rm -r /mnt/isoout
cd out/isoout
sudo unsquashfs system.sfs
sudo chmod -R 777 `pwd`
cd squashfs-root
e2fsck -f system.img
resize2fs system.img 3500M
sudo mount system.img /mnt/system
sudo chmod -R 777 /mnt/system/system/build.prop
#日本語化するための設定を追記
grep -q "ro.product.locale.region=JP" /mnt/system/system/build.prop
if [ $? -ne 0 ] ; then
  echo "ro.product.locale.region=JP" >> /mnt/system/system/build.prop
fi
grep -q "ro.product.locale.language=ja" /mnt/system/system/build.prop
if [ $? -ne 0 ] ; then
  echo "日本語化しました"
  echo "ro.product.locale.language=ja" >> /mnt/system/system/build.prop
fi
sudo chmod -R 600 /mnt/system/system/build.prop
#gappsのあるリンクからダウンロード
wget https://nnlinux.jp/android/gapps.zip
unzip gapps.zip
sudo mkdir /mnt/system/system/media
sudo chmod -R 777 /mnt/system/system/media
sudo cp -r -f system /mnt/system/
sudo chmod -R 755 /mnt/system/system/priv-app
sudo chmod -R 755 /mnt/system/system/app
#個人的にTaskbar好きじゃないから消すww
sudo rm -r /mnt/system/system/priv-app/Taskbar
sudo umount -R /mnt/system
sudo rm -r /mnt/system
e2fsck -f system.img
resize2fs -M system.img
rm ../system.sfs
mksquashfs system.img ../system.sfs -comp gzip
cd ../
sudo rm -r squashfs-root
mkisofs -vJURT  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -input-charset utf-8 -V "Android-x86 (x86)" -o $timedate.iso `pwd`
mv $timedate.iso ../../
cd ../../
rm -r out
echo "完了しました"
