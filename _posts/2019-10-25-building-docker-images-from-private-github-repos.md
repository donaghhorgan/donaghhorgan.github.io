---
title: Building Docker images from private GitHub repos
date: '2019-10-25 13:49:12'
layout: post
tags:
  - docker
---

[Docker](https://docs.docker.com/) has a nice [build context feature](https://docs.docker.com/engine/reference/commandline/build/#git-repositories) that lets you specify a git repository URL as the location to build an image from. So, for instance, you can roll your own Redis image like this:

```shell
docker build -t myredis:5 https://github.com/docker-library/redis.git#master:5.0
```

But things get more complicated if you want to build from a private repository, and more complicated again if you have to deal with SSO.

Let's take the first case: you want to build from a private repository that doesn't have SSO enabled. The only change here is that you need to specify your access credentials in the URL, like this:

```shell
docker build https://${USER}:${PASS}@github.com/my/private.git
```

It's probably not a good idea to use your actual access credentials here because 1) these generally have more privileges than Docker needs and 2) bad things might happen if someone else were to get their hands on them. Instead, you should consider creating a one-off set of credentials with minimal privileges. If you're using GitHub, then you can do this by creating a [personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) (e.g. with `repo` permissions only) and use this in place of your regular password.

Now, consider the second case: your repo is private and access is restricted with SSO. The build line above now fails because your credentials must be further verified via SSO. To get around this, you need to authorise your credentials so that they can be used without requiring manual intervention for SSO. Again, if you're using GitHub, you can [enable SSO](https://help.github.com/en/github/authenticating-to-github/authorizing-a-personal-access-token-for-use-with-saml-single-sign-on) for your personal access tokens pretty easily.

Finally, if you're using [Docker Compose](https://docs.docker.com/compose/), then you can automate this whole process by creating a `.env` file containing your credentials, like this:

```shell
USER=me
PASS=abc123
```

And then defining the corresponding build context, like this:

```yaml
version: ...

services:
  my_private_service:
    build:
      context: https://{USER}:{PASS}@github.com/my/private.git
```
