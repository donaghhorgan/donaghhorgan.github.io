---
title: Accessing Hadoop configuration from PySpark
date: '2020-04-08 16:09:37'
layout: post
tags:
  - pyspark
  - spark
  - hadoop
---

Normally, you don't need to access the underlying Hadoop configuration when you're using PySpark but, just in case you do, you can access it like this:

```python
from pyspark import SparkSession

...

# Extract the configuration
spark = SparkSession.builder.getOrCreate()
hadoop_config = spark._jsc.hadoopConfiguration()

# Set a new config value
hadoop_config.set('my.config.value', 'xyz')

# Get a config value - these are always returned as strings!
dfs_block_size = hadoop_config.get('dfs.block.size')
```

You can also copy the configuration to a dictionary if you want to peruse the entire set of key-value pairs rather than probing one at a time:

```python
# Copy to a dictionary
hadoop_config_dict = {
    e.getKey(): e.getValue()
    for e in hadoop_config.iterator()
}

# Sort by key and print the result
hadoop_config_dict = {
    k: hadoop_config_dict[k]
    for k in sorted(hadoop_config_dict)
}

print(hadoop_config_dict)
```
