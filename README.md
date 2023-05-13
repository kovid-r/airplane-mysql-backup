### Prerequisites

To complete the tutorial, you'll need all of the following:

* A local or remote installation of [MySQL](https://dev.mysql.com/downloads/installer/)
* The [`classicmodels`](https://github.com/hhorak/mysql-sample-db/blob/master/mysqlsampledatabase.sql) sample database schema with data
* The [Airplane CLI](https://docs.airplane.dev/platform/airplane-cli) (a command line tool to interact with Airplane)

Throughout this tutorial, you'll use different commands, SQL scripts, and configurations. All of these are available in the [airplane-mysql-backup GitHub repository](https://github.com/kovid-r/airplane-mysql-backup). You can use this repository to follow along. This tutorial uses macOS as the operating system, but you should be able to achieve the same results on any operating system.

### Configuring Airplane

Installing and configuring Airplane is a straightforward process. First, install the command line tool using the following command:

```shell
brew install airplanedev/tap/airplane
```

If you are on an operating system other than macOS, check the [documentation](https://docs.airplane.dev/platform/airplane-cli) for alternative installation instructions.

Once you've installed Airplane, spin up a `dev` environment for Airplane on your local machine using the following command:

```shell
airplane dev
```

The output of this command is shown below:

![Initializing a dev environment on your local machine using the Airplane CLI](https://i.imgur.com/dE4ygkl.png)

Pressing the Enter key will redirect you to the Airplane web console, where you must log in to your Airplane account. Once you log in, a token will be transmitted to the CLI. After that, your work will be synced to the web console.

### Configuring MySQL

If you are on a Mac-based system, you can use the following command to install MySQL:

```shell
brew install mysql
```

If you are on another operating system, you can use the installation instructions mentioned in the [official MySQL documentation](https://dev.mysql.com/doc/mysql-installation-excerpt/8.0/en/installing.html). You can then check if MySQL is running by executing the `brew services list` command.

Once you install MySQL, you'll need to create a user for your Airplane application.

For simplicity, the following command creates a user called `airplane` with the password `airplanedev` and gives it read privileges on all schemas:

```sql
CREATE USER airplane@localhost IDENTIFIED BY 'airplanedev';
GRANT SELECT, FILE on *.* to airplane@localhost;
```

Though you've granted `FILE` privileges to the user, the user still won't be able to export data from MySQL because of the `secure_file_priv` option. This is enabled by default in a MySQL installation, which means that you cannot import or export data using the `LOAD INFILE` or `SELECT * INTO OUTFILE` commands.

To disable this option, locate and edit the `my.cnf` file to add the following line in the `[mysqld]` option:

```shell
secure_file_priv=''
```

Setting `secure_file_priv` to an empty string allows MySQL to export data anywhere on the file system. Alternatively, you can set this to a specific directory, which is the recommended method in a production environment.

After making any changes to the `[mysqld]` section in the `my.cnf` file, you need to restart the server for the changes to take effect. The following command restarts the server:

```shell
brew services start mysql
```

With MySQL installed and the option to read and write files to disk enabled, you can now create a stored procedure to back up your databases.

### Creating a Stored Procedure to Handle the Backup

MySQL allows you to view data directly in a file or export data from a table. While MySQL supports various file types, this tutorial only uses CSVs.

To export data from a specific table (for example, exporting the `customers` table to `customers.csv`), you could use the following code:

```sql
SELECT * INTO OUTFILE 'customers.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
 LINES TERMINATED BY '\n'
 FROM customers;
```

If you don't specify a directory, the CSV files are written to the default directory on the disk. To find the default export path, you can run the following `SHOW VARIABLES` command:

```sql
SHOW VARIABLES LIKE 'datadir';
```

`datadir` represents the disk location where the table data resides. To avoid confusion with table data files, you should keep the CSV exports in a separate directory. You can specify the export directory at the time of export, as shown in the following command:

```sql 
SELECT * INTO OUTFILE '/path/to/dir/customers.csv'
```

Now, utilizing the `SELECT * INTO OUTFILE` syntax, create the stored procedure to back up the `classicmodels` database using the `backup_procedures.sql` script in the GitHub repository. You'll need to run that script as a SQL statement in your SQL IDE. The procedure loops through every table in the `classicmodels` schema one by one and exports it as a CSV.

You can check out the complete code of the stored procedure [here](https://github.com/kovid-r/airplane-mysql-backup/blob/main/backup_procedures.sql).

### Calling the Stored Procedure from an Airplane SQL Task

You'll wrap an [Airplane task](https://docs.airplane.dev/getting-started/tasks) over the MySQL stored procedure. This task can be manually run or scheduled using the [Airplane scheduler](https://docs.airplane.dev/tasks/schedules). Create an Airplane SQL task from the Airplane CLI using the following command:

```shell
airplane task init
```

This will result in the creation of two files in your working directory:

* `database_backup.sql`, which contains the SQL code you want to execute in this task
* `database_backup.task.yaml`, which contains the configuration for the task that specifies which data resource you want to run which SQL script

The output of the command is shown in the image below:

![Initializing a task using the Airplane CLI](https://i.imgur.com/dp7XRoq.png)

To call the stored procedure, make the following changes to the `database_backup.sql` file:

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

You can also build this SQL task via the console. To do so, create a new SQL task by opening your [Airplane dashboard](https://app.airplane.dev/) and clicking the **+** button on the **Library** menu item in the left panel, as shown in the image below:

![Creating a SQL task using the Airplane console](https://i.imgur.com/N0PJeSz.png)

You can then configure your new SQL task to call the `database_backup` stored procedure, as shown in the image below:

![Building a SQL task using the Airplane console](https://i.imgur.com/96pLu5m.png)

This method will also generate the two files discussed earlier.

### Setting Up a Schedule for the Backup

Airplane provides an internal scheduler that lets you define a schedule using either dropdown menus or a cron expression. To create a new schedule, go to the **Schedules** menu item on the left panel of the console and press the **New schedule** button on the top-right of the screen, as shown in the image below:

![Creating a new schedule using the Airplane console](https://i.imgur.com/9lRFjd3.png)

Now, configure the new schedule:

![Setting up a schedule for your SQL task using the Airplane console](https://i.imgur.com/WV87EVY.png)

Once the schedule is created, your tasks are executed based on that schedule.

### Deploying Your Task Using the Airplane CLI

If you've developed your task using the Airplane CLI, you must deploy it to the Airplane server before you can run it. To develop your task locally, you'll use the `airplane dev` command, and to deploy it, you'll use the `airplane deploy` command, as shown in the image below:

![Deploying to the Airplane server using the CLI](https://i.imgur.com/H6YzNRH.png)

During the deployment or after its completion, you can visit the deployment URL to see the status along with other information, such as logs. You can find the deployment URL in the image above, where it says `View deployment`:

![Successful deployment, as shown on the Airplane console](https://i.imgur.com/vW3Viin.png)

If your deployment is successful, you can run your database backup task manually or on a schedule.
