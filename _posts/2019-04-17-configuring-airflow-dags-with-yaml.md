---
title: Configuring Airflow DAGs with YAML
date: '2019-04-17 09:09:08'
layout: post
tags:
  - airflow
---

[Apache Airflow's documentation](https://airflow.apache.org/index.html) puts a heavy emphasis on the use of its UI client for configuring [DAGs](https://airflow.apache.org/concepts.html#dags). While the UI is nice to look at, it's a pretty clunky way to manage your pipeline configuration, particularly at deployment time. One alternative is to store your DAG configuration in YAML and use it to set the default configuration in the Airflow database when the DAG is first run. This is actually pretty easy using the standard API.

To demonstrate, let's create a simple hello world DAG with an init file (` __init__.py`), a DAG definition file (`dag.py`) and a YAML configuration file (`config.yml`) specifying the default configuration options to use (note: the complete set of files can be found on my Github account [here](https://github.com/donaghhorgan/configuring-airflow-dags-with-yaml)). The structure of the project should look like this:

```shell
$ tree
.
├── __init__.py
├── config.yml
└── dag.py

0 directories, 3 files
```

For this example, we can leave the init file empty - it's just a placeholder file to instruct Airflow to check for a DAG in the folder.

In the config file, let's specify some YAML configuration options for our DAG and our application. First, let's specify our DAG-specific options under key called `dag`. Note that we can specify any supported [DAG configuration key](https://airflow.apache.org/_api/airflow/models/index.html#airflow.models.DAG) here. For now, let's just say we want to create a DAG with the ID `hello-world` and schedule it to run once. Let's also specify some default arguments to pass to operators attached to the DAG and, separately, a list of entities to say hello to under the top level key `say_hello`. An example config file is shown below.

```yaml
dag:
  dag_id: hello-world
  schedule_interval: '@once'
  default_args:
    owner: airflow
    start_date: 2019-01-01T00:00:00Z

say_hello:
  - Sun
  - Moon
  - World
```

Finally, let's write our DAG definition file. Before setting up the DAG itself, we should first load the YAML config and persist it to the Airflow configuration database if configuration has not yet been defined for our application. To do this, we need to load the YAML file (using [PyYAML](https://pypi.org/project/PyYAML/)), convert its contents to JSON, and use the `setdefault` method of Airflow's [Variable](https://airflow.apache.org/_api/airflow/models/index.html#airflow.models.Variable.setdefault) class to persist it to the database if no matching key is found, as shown below. Note that, as PyYAML will deserialize datetimes to Python `datetime.datetime` instances automatically, we must specify `default=str` when dumping to JSON to avoid serialization errors as the `json` module does not support the same automatic serialization/deserialization out of the box.

```python
import json
import yaml

path = Path( __file__ ).with_name(CONFIG_FILE)
with path.open() as f:
    default_config = yaml.safe_load(f)
default_config = json.loads(json.dumps(default_config, default=str))
config = Variable.setdefault(CONFIG_DB_KEY, default_config,
                             deserialize_json=True)
```

Next, we can flesh out our DAG definition as shown below. To keep things simple, we'll just specify a task chain where each new entity to say hello to is bolted on to the last.

```python
import json
from pathlib import Path

import yaml
from airflow import DAG
from airflow.models import Variable
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator

CONFIG_FILE = 'config.yml'
CONFIG_DB_KEY = 'hello_world_config'


def say_hello(name):
    print('Hello, {}'.format(name))


# Load the DAG configuration, setting a default if none is present
path = Path( __file__ ).with_name(CONFIG_FILE)
with path.open() as f:
    default_config = yaml.safe_load(f)
default_config = json.loads(json.dumps(default_config, default=str))
config = Variable.setdefault(CONFIG_DB_KEY, default_config,
                             deserialize_json=True)

# Create the DAG
with DAG(**config['dag']) as dag:
    # Start the graph with a dummy task
    last_task = DummyOperator(task_id='start')

    # Extend the graph with a task for each new name
    for name in config['say_hello']:
        task = PythonOperator(
            task_id='hello_{}'.format(name),
            python_callable=say_hello,
            op_args=(name,)
        )

        last_task >> task
        last_task = task
```

Finally, copy the folder containing the DAG to your Airflow dags directory (usually this is `$AIRFLOW_HOME/dags`), load the UI client and enable the DAG. In the logs for the first created task (to say hello to `Sun`), you should see something like this:

{% raw %}
    *** Reading local file: /usr/local/airflow/logs/hello-world/hello_Sun/2019-01-01T00:00:00+00:00/1.log
    [2019-04-16 16:29:14,324] {{models.py:1359}} INFO - Dependencies all met for <TaskInstance: hello-world.hello_Sun 2019-01-01T00:00:00+00:00 [queued]>
    [2019-04-16 16:29:14,331] {{models.py:1359}} INFO - Dependencies all met for <TaskInstance: hello-world.hello_Sun 2019-01-01T00:00:00+00:00 [queued]>
    [2019-04-16 16:29:14,331] {{models.py:1571}} INFO -
    --------------------------------------------------------------------------------
    Starting attempt 1 of 1
    --------------------------------------------------------------------------------

    [2019-04-16 16:29:14,343] {{models.py:1593}} INFO - Executing <Task(PythonOperator): hello_Sun> on 2019-01-01T00:00:00+00:00
    [2019-04-16 16:29:14,343] {{base_task_runner.py:118}} INFO - Running: ['bash', '-c', 'airflow run hello-world hello_Sun 2019-01-01T00:00:00+00:00 --job_id 3 --raw -sd DAGS_FOLDER/airflow-yaml-config-dag/dag.py --cfg_path /tmp/tmp9rbato60']
    [2019-04-16 16:29:14,822] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun [2019-04-16 16:29:14,822] {{settings.py:174}} INFO - settings.configure_orm(): Using pool settings. pool_size=5, pool_recycle=1800, pid=144
    [2019-04-16 16:29:15,133] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun [2019-04-16 16:29:15,132] {{ __init__.py:51}} INFO - Using executor LocalExecutor
    [2019-04-16 16:29:15,379] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun [2019-04-16 16:29:15,378] {{models.py:273}} INFO - Filling up the DagBag from /usr/local/airflow/dags/airflow-yaml-config-dag/dag.py
    [2019-04-16 16:29:15,446] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun [2019-04-16 16:29:15,446] {{cli.py:520}} INFO - Running <TaskInstance: hello-world.hello_Sun 2019-01-01T00:00:00+00:00 [running]> on host d261a1a58fd5
    [2019-04-16 16:29:15,479] {{python_operator.py:95}} INFO - Exporting the following env vars:
    AIRFLOW_CTX_DAG_ID=hello-world
    AIRFLOW_CTX_TASK_ID=hello_Sun
    AIRFLOW_CTX_EXECUTION_DATE=2019-01-01T00:00:00+00:00
    AIRFLOW_CTX_DAG_RUN_ID=scheduled__2019-01-01T00:00:00+00:00
    [2019-04-16 16:29:15,479] {{logging_mixin.py:95}} INFO - Hello, Sun
    [2019-04-16 16:29:15,480] {{python_operator.py:104}} INFO - Done. Returned value was: None
    [2019-04-16 16:29:15,512] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun /usr/local/lib/python3.6/site-packages/psycopg2/ __init__.py:144: UserWarning: The psycopg2 wheel package will be renamed from release 2.8; in order to keep installing from binary please use "pip install psycopg2-binary" instead. For details see: <http://initd.org/psycopg/docs/install.html#binary-install-from-pypi>.
    [2019-04-16 16:29:15,512] {{base_task_runner.py:101}} INFO - Job 3: Subtask hello_Sun """)
    [2019-04-16 16:29:19,327] {{logging_mixin.py:95}} INFO - [2019-04-16 16:29:19,326] {{jobs.py:2527}} INFO - Task exited with return code 0
{% endraw %}
