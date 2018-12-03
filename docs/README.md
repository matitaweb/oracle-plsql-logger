# ORACLE PLSQL LOGGER


The project contains a simple plsql logger to be used in plslq functions, packages and procedures.

### requirements
- works for oracle 12+
- no needs particurar permissions


### to install
Execute with [sqldeveloper](https://www.oracle.com/database/technologies/appdev/sql-developer.html)

```sql
./oracle_plsql_logger.sql
```

### after installation (DDL)


```sql
  TABLE LOGGER_LOG ; -- a table to save logs
```

Some information for the columns:

| Columns       | info          | 
| ------------- |:-------------:| 
| log_id        | PK AUTO GENERATED | 
| log_sid       | DB connection sid  SYS_CONTEXT ('USERENV', 'SID')    | 
| log_audsid    | DB audit sid useful to group sql call  SYS_CONTEXT ('USERENV', 'SESSIONID')   | 
| log_level     | the log row level TRACE,DEBUG,INFO,WARN,ERROR      | 
| log_line      | the program where log are called utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(..))      | 
| log_line_num  | the line number where the log is called utl_call_stack.unit_line()      | 
| log_info      | some info       | 
| log_timestamp | SYSTIMESTAMP      | 
| created_by    | USER      | 
| start_time_trace_num    | useful for time trace     | 
| end_time_trace_num    | useful for time trace       | 
| errorcode    | SQLCODE      | 
| callstack    | DBMS_UTILITY.format_call_stack      | 
| errorstack    | DBMS_UTILITY.format_error_stack     | 
| backtrace    | DBMS_UTILITY.format_error_backtrace      | 


```
CREATE TABLE LOGGER_LOG_CFG; -- a table to config to manage and enable LOG LEVES
```

Some information for the columns:

| Columns    | info          | 
| --------- |:-------------:| 
| LOG_SRC   | source name of caller procedure/package, * for wildcard | 
| LOG_LEVEL | contains a list of levels enabled: TRACE,DEBUG,INFO,WARN,ERROR       | 
| MEMO      | a space for comments and memo to explain some choices    | 



### how to use (EXAMPLE)

Write some code and ad some log in LOGGER_TEST_PROCEDURE example:

``` sql
CREATE OR REPLACE PROCEDURE LOGGER_TEST_PROCEDURE AS 
BEGIN
-- to log simple add the rows
  LOGGER.error('some error to log...');  
  LOGGER.warn('some warn to log...');  
  LOGGER.info('some info to log...');  
  LOGGER.debug('some debug info to log...');  
  LOGGER.trace('some trace info to log...');    
END LOGGER_TEST_PROCEDURE;
```

to enable  the logs add a row in LOGGER_LOG_CFG

example

| LOG_SRC               | LOG_LEVEL      | MEMO| 
| ---------             |:-------------:| :-------------:|
|LOGGER_TEST_PROCEDURE  | INFO,WARN,ERROR| Enable only some levels for LOGGER_TEST_PROCEDURE |
| ...  | ... |  ... |


See what happen in LOGGER_LOG executing LOGGER_TEST_PROCEDURE()

``` sql
BEGIN
  LOGGER_TEST_PROCEDURE();
--rollback; 
END;
```


------


Some project with the same topic:

https://livesql.oracle.com/apex/livesql/file/content_C2PSKGN84HZDO1OEEJTVLUC5M.html
http://www.oaktable.net/content/oracle-12c-%E2%80%93-utlcallstack-easier-debugging
https://blogs.oracle.com/oraclemagazine/sophisticated-call-stack-analysis
https://idlesummerbreeze.wordpress.com/2014/08/27/what-is-die-difference-between-sessionid-and-sid-in-userenv-context/

