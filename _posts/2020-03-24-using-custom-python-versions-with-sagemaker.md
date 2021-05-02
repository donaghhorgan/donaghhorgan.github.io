---
title: Using custom Python versions with SageMaker
date: '2020-03-24 09:00:00'
layout: post
tags:
  - python
  - sagemaker
  - aws
---

Currently (as of March 2020), SageMaker supports Python 3.6 kernels only, which means you can't run any 3.7 or 3.8 code out of the box. Fortunately, there's an easy (though not well documented) fix:

```shell
name="my-env"
version="3.7"

# Create a new conda environment for the given Python version
conda create -y -n "$name" python="$version"

# Activate the environment
source /home/ec2-user/anaconda3/bin/activate "$name"

# Create a Jupyter kernel for your new environment
pip install ipykernel
python -m ipykernel install --name "$name" --display-name "$name" --user

# Deactivate the environment
source /home/ec2-user/anaconda3/bin/deactivate
```

For maximum laziness, bundle this script into your &nbsp;`on-setup.sh` [lifecycle configuration](https://docs.aws.amazon.com/sagemaker/latest/dg/notebook-lifecycle-config.html) script.
