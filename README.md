# Creating MySQL database backup using Airplane

## Prerequisites

* [MySQL](https://dev.mysql.com/downloads/installer/) - a local or remote installation of MySQL.
* [Classic Models](https://github.com/hhorak/mysql-sample-db/blob/master/mysqlsampledatabase.sql) - a sample database schema with data.
* [Airplane CLI](https://docs.airplane.dev/platform/airplane-cli) - a command-line tool to interact with Airplane.

## Configuring Airplane

Installing and configuring Airplane is simple. First, you have to install the command line tool using the following command:

```shell
brew install airplanedev/tap/airplane
```

If you are on any other operating system, you can check out [this link](https://docs.airplane.dev/platform/airplane-cli) for the installation instructions.
Once you are done installing Airplane, spin up a `dev` environment for Airplane on your local machine using the following command:

```shell
airplane dev
```

The output of this command is shown below:

![Initializing a dev environment on your local machine using the Airplane CLI - Image by author](https://i.imgur.com/dE4ygkl.png)

Pressing the return key will redirect you to the Airplane web console, where you must log into your Airplane account. Once you log in, a token will be transmitted to the CLI. After that, your work will be synced to the web console.

## Configuring MySQL

Installing MySQL is also very easy. If you are on a Mac-based system, you can use the following command to install MySQL:

```shell
brew install mysql
```

If you are on other operating systems, you can use the instructions mentioned in the [official MySQL documentation](https://dev.mysql.com/doc/mysql-installation-excerpt/8.0/en/installing.html). You can check if MySQL is running by executing the `brew services list` command.

Once you install MySQL, you must create a user for your Airplane application. For simplicity's sake, we'll create a user called `airplane` with the password `airplanedev` and give it read privileges on all schemas using the following commands:

```sql
CREATE USER airplane@localhost IDENTIFIED BY 'airplanedev';
GRANT SELECT, FILE on *.* to airplane@localhost;
```

While you have granted `FILE` privileges to the user, the user still won't be able to export data from MySQL because of the `secure_file_priv` option, which is the default setting for a MySQL installation. To disable this option, locate and edit the `my.cnf` file to add the following line in the `[mysqld]` option:

```shell
secure_file_priv=''
```

After adding anything to the `[mysqld]` section in the `my.cnf` file, you need to restart the server. Use the following command to do that:

```shell
brew services start mysql
```

With MySQL installed and the option to read and write files to disk, you can now create a stored procedure to back up your databases.
### Create a stored procedure to handle the backup
MySQL allows you to export data from a table or view it directly into a file. The file can be of various types, but for the scope of this article, we'll only use CSVs. The following sentence can help you export data from, for example, the `customers` table to `customers.csv`:

```sql
SELECT * INTO OUTFILE 'customers.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
 LINES TERMINATED BY '\n'
 FROM customers;
```

These CSV files are written to disk, but it is usually not completely obvious where exactly they are. To find out the export path, you can run the following `SHOW VARIABLES` command:

```sql
SHOW VARIABLES LIKE 'datadir';
```

The `datadir` is the disk location where the table data resides. To avoid any confusion, you should change the location of the CSV exports. You can do that by using your desired directory's full path in the export path.

```sql 
SELECT * INTO OUTFILE '/path/to/dir/customers.csv'
```

Based on the `SELECT * INTO OUTFILE` syntax, create the stored procedure to back up the `classicmodels` database. The procedure loops through every table in the `classicmodels` schema one by one and exports it as a CSV. You can check out the complete code of the stored procedure [here](https://github.com/kovid-r/airplane-mysql-backup/blob/main/backup_procedures.sql).

## Call the stored procedure from an Airplane SQL Task

An Airplane Task wraps over the MySQL stored procedure. The task can be manually run or scheduled using the Airplane Scheduler. Create an Airplane SQL Task from the Airplane CLI using the following command:

```shell
airplane task init
```

This will result in the creation of two files in your working directory:

* `database_backup.sql` - The SQL code you want to execute in this task.
* `database_backup.task.yaml` - The configuration for the task that mentions which data resource you want to run which SQL script.

The output of the command is shown in the image below:

![](https://i.imgur.com/dp7XRoq.png)

First, edit the `database_backup.sql` file to call the stored procedure:

```sql 
CALL classicmodels.database_backup();
```

Then, replace the contents of the `database_backup.task.yaml` file with the following configuration:

```yaml
slug: database_backup
name: Database Backup
sql:
 resource: mysql
 entrypoint: database_backup.sql
```

Another way to build a SQL task is to go to the console and configure it, as shown in the image below:

![](https://i.imgur.com/96pLu5m.png)

Doing this will also generate the two files we discussed earlier.

## Setup a schedule for the backup

Airplane provides you with an internal scheduler that lets you define a schedule using either drop-down menus or a cron expression, as shown in the image below:

![](https://i.imgur.com/WV87EVY.png)

Once the schedule is created, your task will be executed based on that schedule.

## Deploy your task using the Airplane CLI

If you've developed your task using the Airplane CLI, you must deploy it to the Airplane server before expecting it to run. To develop your task locally, you use the `airplane dev` command, and to deploy it, you'll need to use the `airplane deploy` command, as shown in the image below:

![](https://i.imgur.com/H6YzNRH.png)

During the deployment or after its completion, you can visit the deployment URL to see the status along with other information, such as logs:

![](https://i.imgur.com/vW3Viin.png)

If your deployment is successful, you can run your database backup task manually or on a schedule.
