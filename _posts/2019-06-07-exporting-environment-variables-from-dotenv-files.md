---
title: Exporting environment variables from dotenv files
date: '2019-06-07 16:40:54'
layout: post
tags:
  - bash
---

Here's a nice shortcut for bash that exports all environment variables from a dotenv (.env) file into the current terminal session:

```shell
export $(cat .env | xargs)
```
