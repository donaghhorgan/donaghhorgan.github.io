---
title: Using pipenv with SageMaker
date: '2020-03-23 15:12:44'
layout: post
tags:
  - pipenv
  - python
  - sagemaker
  - aws
---

SageMaker uses `conda` for package management, which complicates things if you manage packages for your project with `pipenv`. One quick workaround is to use `pipenv` to generate a `requirements.txt` file and pipe the output to `pip` which then modifies the active `conda` environment:

```shell
# Activate the conda environment you want to modify
source /home/ec2-user/anaconda3/bin/activate my-env

# Install packages from pipenv
pipenv lock -r | pip install -r /dev/stdin

# Deactivate the conda environment
source /home/ec2-user/anaconda3/bin/deactivate
```
