# dockershell
A simple user shell backed by Docker containers.

#### Table of Contents

1. [Overview](#overview)
1. [Configuration](#configuration)
    * [Profiles](#profiles)
1. [Usage Suggestions](#usage-suggestions)
1. [Limitations](#limitations)

## Overview

Dockershell can be used as a user login shell, or simply run on the CLI. It
will stand up a Docker container and then drop the user into a bash shell
on the container. It's highly configurable and supports multiple profiles.

Note: When combined with my [Abalone](https://github.com/binford2k/abalone) web
terminal project, this allows you to expose Docker-backed shells to a web browser.
See [usage suggestions](#usage-suggestions) below.

## Configuration

The configuration is always loaded from `/etc/dockershell/config.yaml`. For security
purposes, this location is not relocatable or configurable. Sensible defaults are
provided, so configuration is not strictly required.

* `:loglevel`
    * Standard log levels: `:fatal`, `:error`, `:warn`, `:info`, `:debug`
    * Default value: `:warn`
* `:logfile`
    * Where you want to log to.
    * Default value: `/var/log/dockershell`
*  `:domain`
    * The domain to use for container FQDNs
    * Default value: the domain of the host.
* `:docker`
    * A `Hash` of Docker settings.
    * `:group`
        * The group allowed to access Docker containers.
        * Default value: `docker`
    * `:ipaddr`
        * The address of the Docker network interface.
        * Default value: the address of interface `docker0`
    
#### Example:

``` yaml
---
:loglevel: :warn
:logfile: /var/log/dockershell
:domain: try.puppet.com
:docker:
    :group: docker
    :ipaddr: 1.2.3.4
```

### Profiles

Profiles are how you configure different ways to run the shell. Without a profile,
Dockershell will simply log you into a new container and destroy it when you log
out. By defining a profile, you can specify the container name and a series of
scripts that you can use to configure the container.

Each key of the `:profiles` hash should be the name of a profile. In the following
example, two profiles (`learn` and `docs`) are defined:


``` Yaml
---
:profiles:
    :learn:
      :image: agent
      :prerun: pe_classify
      :setup: course_selector
      :postrun: pe_purge
    :docs:
      :image: agent
```

Each profile has a number of options you can configure. None have default values.

* `:image`
    * The name of the Docker image to run.
    * Required.
* `:prerun`
    * The name of a script to run before the container is created.
*  `:setup`
    * A script to run after the container is started, but before the user is logged in.
*  `:postrun`
    * The cleanup script to run after the session has ended. It is run in a detached
      process so that it's guaranteed to complete even if the shell is killed.
    * *This will not execute if the shell is terminated with signal 9 (`SIGKILL`)!*

Each script should exist in `/etc/dockershell/scripts`. A few defaults are provided
directly in the gem. The script is executed with two values passed:

1. `ARGV[0]` is the FQDN of the container node.
    * The first segment will be the name of the container.
1. `ARGV[1]` is the value of the optional `--option` parameter.

#### Built in scripts:

* `pe_classify` will pin the container to a new environment group in the PE Console.
    * An environment directory is created on disk if needed.
* `pe_purge` will remove the container from the Puppet Enterprise infrastructure.
    * The environment directory is removed.
    * The environment node group is removed.
    * The node's certificate is cleaned.
    * The node is purged from PuppetDB.
* `course_selector` will classify the new node with the name of a Puppet Education course.
    * Pass the course name to Dockershell with `--option`
    

## Usage Suggestions

When combined with my [Abalone](https://github.com/binford2k/abalone) web
terminal project, this allows you to expose Docker-backed shells to a web
browser. The Abalone configuration could look like:

``` yaml
---
:port: 9000
:bind: 0.0.0.0
:logfile: /var/log/abalone
:bannerfile: /etc/dockershell/banner
:command: /usr/local/bin/dockershell
:timeout: 900
:ttl: 60
:params: ['profile', 'option']
```

If you prefer to be more prescriptive, you can specify allowed values for
parameters, such as:

``` yaml
:params:
  profile:
    :values: ['learn', 'docs']
  option:
    :values:
      - default
      - hiera
      - parser
      - testing
```

Then you would simply load the web terminal with a URL such as:
http://login.example.com:9000/?profile=learn&option=parser


## Limitations

This is super early in development and has not yet been battle tested.


## Disclaimer

I take no liability for the use of this tool.

Contact
-------

binford2k@gmail.com
