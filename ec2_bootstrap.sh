#!/bin/bash

# Update and install critical packages
LOG_FILE="/home/ubuntu/ec2_bootstrap.sh.log"
touch $LOG_FILE
echo "Logging to \"$LOG_FILE\" ..."

echo "Installing essential packages via apt-get in non-interactive mode ..." | tee -a $LOG_FILE
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" upgrade
sudo apt-get install -y zip unzip curl bzip2 python-dev build-essential git libssl1.0.0 libssl-dev \
    software-properties-common debconf-utils apt-transport-https

# Update the motd message to warn incompleteness
echo "Updating motd boot message to warn setup incomplete ..." | tee -a $LOG_FILE
sudo apt-get install -y update-motd
cat > /home/ubuntu/agile_data_science.message << END_HELLO

------------------------------------------------------------------------------------------------------------------------

This system is not yet done loading! It will not work yet. Come back in a few minutes. This can take as long as 20 minutes because there are large files to download.

END_HELLO

cat <<EOF | sudo tee /etc/update-motd.d/99-agile-data-science
#!/bin/bash

cat /home/ubuntu/agile_data_science.message
EOF
sudo chmod 0755 /etc/update-motd.d/99-agile-data-science
sudo update-motd

# Intall OpenJDK 8 - Oracle Java no longer available
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /home/ubuntu/.bash_profile

# Install Miniconda
echo "Installing and configuring miniconda3 latest ..." | tee -a $LOG_FILE
curl -Lko /tmp/Miniconda3-latest-Linux-x86_64.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod +x /tmp/Miniconda3-latest-Linux-x86_64.sh 
/tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /home/ubuntu/anaconda

export PATH=/home/ubuntu/anaconda/bin:$PATH # setup .bash_profile at end

sudo chown -R ubuntu:ubuntu /home/ubuntu/anaconda

# Clone repo, install Python dependencies
echo "Cloning https://github.com/rjurney/Agile_Data_Code_2 repository and installing dependencies ..." \
  | tee -a $LOG_FILE
cd /home/ubuntu
git clone https://github.com/rjurney/Agile_Data_Code_2
cd /home/ubuntu/Agile_Data_Code_2
export PROJECT_HOME=/home/ubuntu/Agile_Data_Code_2
echo "export PROJECT_HOME=/home/ubuntu/Agile_Data_Code_2" | sudo tee -a /home/ubuntu/.bash_profile
conda install -y python=3.13.0
conda update -y -n base conda
conda install -y tornado=6.4.1 # To deal with https://github.com/jupyter/notebook/issues/3544
conda install -y iso8601 numpy scipy scikit-learn matplotlib ipython jupyter
pip install --upgrade pip
pip install -r requirements.txt
sudo chown -R ubuntu:ubuntu /home/ubuntu/Agile_Data_Code_2
cd /home/ubuntu

# Install commons-httpclient
curl -Lko /home/ubuntu/Agile_Data_Code_2/lib/commons-httpclient-3.1.jar http://central.maven.org/maven2/commons-httpclient/commons-httpclient/3.1/commons-httpclient-3.1.jar

# Install Hadoop
echo "" | tee -a $LOG_FILE
echo "Downloading and installing Hadoop 3.0.1 ..." | tee -a $LOG_FILE
curl -Lko /tmp/hadoop-3.4.0.tar.gz https://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-3.4.0/hadoop-3.4.0-src.tar.gz
mkdir -p /home/ubuntu/hadoop
cd /home/ubuntu/
tar -xvf /tmp/hadoop-3.4.0.tar.gz -C hadoop --strip-components=1

echo "Configuring Hadoop 3.4.0 ..." | tee -a $LOG_FILE
echo "" >> /home/ubuntu/.bash_profile
echo '# Hadoop environment setup' | sudo tee -a /home/ubuntu/.bash_profile
export HADOOP_HOME=/home/ubuntu/hadoop
echo 'export HADOOP_HOME=/home/ubuntu/hadoop' | sudo tee -a /home/ubuntu/.bash_profile
export PATH=$PATH:$HADOOP_HOME/bin
echo 'export PATH=$PATH:$HADOOP_HOME/bin' | sudo tee -a /home/ubuntu/.bash_profile
export HADOOP_CLASSPATH=$(hadoop classpath)
echo 'export HADOOP_CLASSPATH=$(hadoop classpath)' | sudo tee -a /home/ubuntu/.bash_profile
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' | sudo tee -a /home/ubuntu/.bash_profile

# Give to ubuntu
echo "Giving hadoop to user ubuntu ..." | tee -a $LOG_FILE
sudo chown -R ubuntu:ubuntu /home/ubuntu/hadoop

# Install Spark
echo "" | tee -a $LOG_FILE
echo "Downloading and installing Spark 3.5.3 ..." | tee -a $LOG_FILE
curl -Lko /tmp/spark-3.5.3-bin-hadoop3.tgz https://www.apache.org/dyn/closer.lua/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz
mkdir -p /home/ubuntu/spark
cd /home/ubuntu
tar -xvf /tmp/spark-3.5.3-bin-hadoop3.tgz -C spark --strip-components=1
cd spark/python

echo "Configuring Spark 3.5.3 ..." | tee -a $LOG_FILE
echo "" >> /home/ubuntu/.bash_profile
echo "# Spark environment setup" | sudo tee -a /home/ubuntu/.bash_profile
export SPARK_HOME=/home/ubuntu/spark
echo 'export SPARK_HOME=/home/ubuntu/spark' | sudo tee -a /home/ubuntu/.bash_profile
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop/
echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop/' | sudo tee -a /home/ubuntu/.bash_profile
export SPARK_DIST_CLASSPATH=`$HADOOP_HOME/bin/hadoop classpath`
echo 'export SPARK_DIST_CLASSPATH=`$HADOOP_HOME/bin/hadoop classpath`' | sudo tee -a /home/ubuntu/.bash_profile
export PATH=$PATH:$SPARK_HOME/bin
echo 'export PATH=$PATH:$SPARK_HOME/bin' | sudo tee -a /home/ubuntu/.bash_profile

# Have to set spark.io.compression.codec in Spark local mode
cp /home/ubuntu/spark/conf/spark-defaults.conf.template /home/ubuntu/spark/conf/spark-defaults.conf
echo 'spark.io.compression.codec org.apache.spark.io.SnappyCompressionCodec' | sudo tee -a /home/ubuntu/spark/conf/spark-defaults.conf

# Configure Spark for an r5.xlarge with Python3
echo "spark.driver.memory 25g" | sudo tee -a $SPARK_HOME/conf/spark-defaults.conf
echo "spark.executor.cores 4" | sudo tee -a $SPARK_HOME/conf/spark-defaults.conf
echo "PYSPARK_PYTHON=python3" | sudo tee -a $SPARK_HOME/conf/spark-env.sh
echo "PYSPARK_DRIVER_PYTHON=python3" | sudo tee -a $SPARK_HOME/conf/spark-env.sh

# Setup log4j config to reduce logging
cp $SPARK_HOME/conf/log4j.properties.template $SPARK_HOME/conf/log4j.properties
sed -i 's/INFO/ERROR/g' $SPARK_HOME/conf/log4j.properties

# Give to ubuntu
echo "Giving spark to user ubuntu ..." | tee -a $LOG_FILE
sudo chown -R ubuntu:ubuntu /home/ubuntu/spark

# Kafka install and setup
echo "" | tee -a $LOG_FILE
echo "Downloading and installing Kafka version 2.1.1 for Scala 2.11 ..." | tee -a $LOG_FILE
curl -Lko /tmp/kafka_2.13-3.9.0.tgz https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
mkdir -p /home/ubuntu/kafka
cd /home/ubuntu/
tar -xvzf /tmp/kafka_2.13-3.9.0.tgz -C kafka --strip-components=1 && rm -f /tmp/kafka_2.13-3.9.0.tgz

# Give to ubuntu
echo "Giving Kafka to user ubuntu ..." | tee -a $LOG_FILE
sudo chown -R ubuntu:ubuntu /home/ubuntu/kafka

# Set the log dir to kafka/logs
echo "Configuring logging for kafka to go into kafka/logs directory ..." | tee -a $LOG_FILE
sed -i '/log.dirs=\/tmp\/kafka-logs/c\log.dirs=logs' /home/ubuntu/kafka/config/server.properties

# Run zookeeper, then Kafka
echo "Running Zookeeper as a daemon ..." | tee -a $LOG_FILE
sudo -H -u ubuntu /home/ubuntu/kafka/bin/zookeeper-server-start.sh -daemon /home/ubuntu/kafka/config/zookeeper.properties
echo "Running Kafka Server as a daemon ..." | tee -a $LOG_FILE
sudo -H -u ubuntu /home/ubuntu/kafka/bin/kafka-server-start.sh -daemon /home/ubuntu/kafka/config/server.properties

# Install and setup Airflow
echo "" | tee -a $LOG_FILE
echo "Installing Airflow via pip ..." | tee -a $LOG_FILE
pip install airflow[hive]
mkdir /home/ubuntu/airflow
mkdir /home/ubuntu/airflow/dags
mkdir /home/ubuntu/airflow/logs
mkdir /home/ubuntu/airflow/plugins

echo "Giving airflow directory to user ubuntu ..." | tee -a $LOG_FILE
sudo chown -R ubuntu:ubuntu /home/ubuntu/airflow

airflow initdb
airflow webserver -D &
airflow scheduler -D &

echo "Giving airflow directory to user ubuntu yet again and putting same in .bash_profile ..." | tee -a $LOG_FILE
sudo chown -R ubuntu:ubuntu /home/ubuntu/airflow
echo "sudo chown -R ubuntu:ubuntu /home/ubuntu/airflow" | sudo tee -a /home/ubuntu/.bash_profile



# Use Anaconda Python
export PATH=/home/ubuntu/anaconda/bin:$PATH
echo 'export PATH=/home/ubuntu/anaconda/bin:$PATH' | sudo tee -a /home/ubuntu/.bash_profile

# make sure we own ~/.bash_profile after lots of 'sudo tee'
sudo chown ubuntu:ubuntu ~/.bash_profile

# Update the motd message to create instructions for ssh users
echo "Updating motd boot message with instructions for the user of the image ..." | tee -a $LOG_FILE
sudo apt-get install -y update-motd
cat > /home/ubuntu/agile_data_science.message << END_HELLO

----------------------------------------------------------------------------------------------------------------------
Welcome to Agile Data Science 2.0!

If the Agile_Data_Code_2 directory (and others for hadoop, spark, mongodb, elasticsearch, etc.) aren't present, please wait for the install script to finish.

The data has already been downloaded but if you need to do so:


# Cleanup
echo "Cleaning up ..." | tee -a $LOG_FILE
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
