#!/bin/bash

#learn the linux distribution
DISTRIB_ID=Centos
if [[ -e /etc/lsb-release ]]; then source /etc/lsb-release; fi
echo "DISTRIB_ID=$DISTRIB_ID"

EPHEMERAL_HDFS=~/ephemeral-hdfs
USER=`whoami`

# Set hdfs url to make it easier
HDFS_URL="hdfs://$PUBLIC_DNS:9000"
echo "export HDFS_URL=$HDFS_URL" >> ~/.bash_profile

pushd ~/spark-ec2/ephemeral-hdfs > /dev/null
source ./setup-slave.sh

for node in $SLAVES $OTHER_MASTERS; do
  echo $node
  ssh -t -t $SSH_OPTS $USER@$node "~/spark-ec2/ephemeral-hdfs/setup-slave.sh" & sleep 0.3
done
wait

~/spark-ec2/copy-dir $EPHEMERAL_HDFS/conf

NAMENODE_DIR=/mnt/ephemeral-hdfs/dfs/name

if [ -f "$NAMENODE_DIR/current/VERSION" ] && [ -f "$NAMENODE_DIR/current/fsimage" ]; then
  echo "Hadoop namenode appears to be formatted: skipping"
else
  echo "Formatting ephemeral HDFS namenode..."
  $EPHEMERAL_HDFS/bin/hadoop namenode -format
fi

echo "Starting ephemeral HDFS..."

# This is different depending on version.
case "$HADOOP_MAJOR_VERSION" in
  1)
    if [[ $DISTRIB_ID = "Ubuntu" ]]; then
      echo "ERROR: Unsupported hadoop version on Ubuntu"
      return -1
    fi
    $EPHEMERAL_HDFS/bin/start-dfs.sh
    ;;
  2)
    if [[ $DISTRIB_ID = "Ubuntu" ]]; then
      [[ ! -e /var/hadoop ]] && sudo mkdir /var/hadoop
      sudo chmod 777 /var/hadoop
    fi
    $EPHEMERAL_HDFS/sbin/start-dfs.sh
    ;;
  yarn) 
    if [[ $DISTRIB_ID = "Ubuntu" ]]; then
      [[ ! -e /var/hadoop ]] && sudo mkdir /var/hadoop 
      sudo chmod 777 /var/hadoop
    fi
    $EPHEMERAL_HDFS/sbin/start-dfs.sh
    echo "Starting YARN"
    $EPHEMERAL_HDFS/sbin/start-yarn.sh
    ;;
  *)
     echo "ERROR: Unknown Hadoop version"
     return -1
esac

popd > /dev/null
