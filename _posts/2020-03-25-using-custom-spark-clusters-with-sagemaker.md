---
title: Using custom Spark clusters (and interactive PySpark!) with SageMaker
date: '2020-03-25 09:00:00'
layout: post
tags:
  - python
  - pyspark
  - spark
  - flintrock
  - aws
---

Amazon EMR seems like the natural choice for running production Spark clusters on AWS, but it's not so suited for development because [it doesn't support interactive PySpark sessions](https://aws.amazon.com/premiumsupport/knowledge-center/emr-submit-spark-job-remote-cluster/) (at least as of the time of writing) and so rolling a custom Spark cluster seems to be the only option, particularly if you're developing with SageMaker.

This isn't actually as daunting as it sounds. You can do it in three easy steps:

1. Roll a custom Spark cluster with [flintrock](https://github.com/nchammas/flintrock)
2. Install Spark binaries on your SageMaker notebook instance
3. Install PySpark and connect to your cluster from SageMaker

# Rolling a custom cluster with flintrock

[Flintrock](https://github.com/nchammas/flintrock) is a simple command line tool that allows you to orchestrate and administrate Spark clusters on EC2 with minimal configuration and hassle. Once you have a minimal configuration defined, spinning up a brand new cluster with tens of nodes takes less than five minutes.

I won't go into deep detail about the flintrock setup (for that, see Heather Miller's excellent and very detailed post [here](https://heather.miller.am/blog/launching-a-spark-cluster-part-1.html)) but one thing to note is that it's important to create a custom security group for your cluster (that is, aside from the `flintrock` and `flintrock-*` groups that flintrock creates itself) so that you can add your SageMaker notebook instance to the same group later - otherwise, you'll end up with siloed resources that can't talk to one another. You might be tempted to just add your notebook to the `flintrock-*` security group, but this [can cause problems later if you try to terminate your cluster](https://github.com/nchammas/flintrock/issues/219).

Once your cluster has been created, run the following script to figure out the private IP address of your cluster master node on the subnet where you'll add your SageMaker notebook instance to - you'll need this later in order to point PySpark at your cluster master.

```shell
# Get the public DNS of your cluster master
master_dns=$(flintrock --config "config.yml" describe "my-cluster" | grep "master" | awk -F "master: " '{ print $2}')

# Look up the private IP address of your cluster master
aws ec2 describe-instances --filters "Name=dns-name, Values=$master_dns" | jq -r '.Reservations[0].Instances[0].PrivateIpAddress'
```

# Installing Spark binaries on SageMaker

Next, create a Jupyter Notebook instance and assign it to the same VPC, subnet and security group that you specified when creating your cluster with flintrock. Start the instance, open a terminal and run the following script to set the environment variables and install Spark binaries:

```shell
sudo -i <<EOF

# Set environment variables
SPARK_LOCAL_IP="A.B.C.D" # This should be the IP address of your SageMaker notebook instance on the same subnet that the cluster is running on
PYSPARK_PYTHON="python3" # Or whatever Python you like
SPARK_HOME="/opt/spark"

env_file="/etc/profile.d/jupyter-env.sh"
touch "$env_file"
{
  echo "export SPARK_LOCAL_IP=$SPARK_LOCAL_IP"
  echo "export PYSPARK_PYTHON=$PYSPARK_PYTHON"
  echo "export SPARK_HOME=$SPARK_HOME"
  echo "export PATH=$SPARK_HOME/bin:$PATH"
} >> "$env_file"
source "$env_file"

# Download and install Spark
url="https://ftp.heanet.ie/mirrors/www.apache.org/dist/spark/spark-2.4.5/spark-2.4.5-bin-hadoop2.7.tgz"
filename="$(basename "$url")"
if [! -d "$SPARK_HOME"]; then
  wget "$url"
  tar -xzf "$filename"
  mv "${filename%.*}" "$SPARK_HOME"
fi

# Restart the Jupyter server for changes to take effect
initctl restart jupyter-server --no-wait

EOF
```

If you use [lifecycle configuration scripts](https://docs.aws.amazon.com/sagemaker/latest/dg/notebook-lifecycle-config.html), you can add the code between the `EOF` tags above to your `on-setup.sh` to automatically install Spark each time you start your instance, although you'll need to figure out how to compute the value of `SPARK_LOCAL_IP` programatically (in my case, I filter the output of `hostname -I` based on the CIDR block assigned to my VPC).

# Installing PySpark and connecting to the cluster

Next, select (or [create](/using-custom-python-versions-with-sagemaker)) a conda environment to work with and install the `pyspark` package:

```shell
# Activate your conda environment
source /home/ec2-user/anaconda3/bin/activate my-env

# Install the pyspark package
pip install pyspark
```

Finally, create a new Jupyter notebook instance from your updated conda environment and try a word count example to test things out:

```python
from pyspark.sql import SparkSession

master_ip = '...' # Whatever your cluster master private IP was earlier
spark = SparkSession.builder\
                    .master(f'spark:{master_ip}//:7077') \
                    .getOrCreate()
sc = spark.sparkContext

text = 'the quick brown fox jumps over the lazy dog'
rdd = sc.parallelize([text])
counts = rdd.flatMap(lambda line: line.split()) \
            .map(lambda word: (word, 1)) \
            .reduceByKey(lambda x, y: x + y)
counts.collect()
```
