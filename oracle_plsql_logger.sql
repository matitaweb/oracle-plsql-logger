/*
some article 
https://livesql.oracle.com/apex/livesql/file/content_C2PSKGN84HZDO1OEEJTVLUC5M.html
http://www.oaktable.net/content/oracle-12c-%E2%80%93-utlcallstack-easier-debugging
https://blogs.oracle.com/oraclemagazine/sophisticated-call-stack-analysis
https://idlesummerbreeze.wordpress.com/2014/08/27/what-is-die-difference-between-sessionid-and-sid-in-userenv-context/

For Oracle 12g  
*/


/* DROP TABLE IF EXIST 
https://stackoverflow.com/questions/1799128/oracle-if-table-exists
*/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE LOGGER_LOG';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;
/

/* LOGGER TABLE */
CREATE TABLE LOGGER_LOG 
( 
   log_id                   NUMBER GENERATED ALWAYS AS IDENTITY, 
   log_sid                  NUMBER,
   log_audsid               NUMBER,
   log_level                VARCHAR2(6),
   log_line                 VARCHAR(500),
   log_line_num             NUMBER,
   log_timestamp            TIMESTAMP WITH LOCAL TIME ZONE,     
   log_info                 VARCHAR2 (4000), 
   created_by               VARCHAR2 (200), 
   start_time_trace_num     NUMBER,   
   end_time_trace_num       NUMBER,       
   errorcode                INTEGER, 
   callstack                VARCHAR2 (4000), 
   errorstack               VARCHAR2 (4000), 
   backtrace                VARCHAR2 (4000) 
   
);
/

COMMENT ON TABLE LOGGER_LOG                 IS 'logging table for procedures/packages debug/audit';
COMMENT ON COLUMN LOGGER_LOG.LOG_SID        IS 'DB connection sid';
COMMENT ON COLUMN LOGGER_LOG.LOG_AUDSID     IS 'DB audit sid useful tu group sql call';
COMMENT ON COLUMN LOGGER_LOG.LOG_LEVEL      IS 'one value between TRACE,DEBUG,INFO,WARN,ERROR';
COMMENT ON COLUMN LOGGER_LOG.LOG_LINE       IS 'source name of caller procedure/package';
COMMENT ON COLUMN LOGGER_LOG.LOG_LINE_NUM   IS 'source line number of caller procedure/package';
COMMENT ON COLUMN LOGGER_LOG.LOG_INFO       IS 'log user content';


/* DROP TABLE IF EXIST 
https://stackoverflow.com/questions/1799128/oracle-if-table-exists
*/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE LOGGER_LOG_CFG';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;
/


/*
LOG CONFIGURATION FOR EVERY PACKAGE / PROCEDURE
*/
CREATE TABLE LOGGER_LOG_CFG
(
   LOG_SRC     VARCHAR2 (200) NOT NULL,
   LOG_LEVEL   VARCHAR2 (300) NOT NULL,
   MEMO        VARCHAR2 (4000)
);
/


ALTER TABLE LOGGER_LOG_CFG ADD CONSTRAINT PK_LOGGER_LOG_CFG PRIMARY KEY (LOG_SRC);

COMMENT ON TABLE LOGGER_LOG_CFG IS 'logging config';
COMMENT ON COLUMN LOGGER_LOG_CFG.LOG_SRC    IS 'source name of caller procedure/package, * for wildcard';
COMMENT ON COLUMN LOGGER_LOG_CFG.LOG_LEVEL  IS ' contains a list of levels TRACE,DEBUG,INFO,WARN,ERROR';
COMMENT ON COLUMN LOGGER_LOG_CFG.memo IS 'memo/comment/remark';


/* SETUP CONFIGURATION FOR TESTS: */
SET DEFINE OFF;
Insert into LOGGER_LOG_CFG (LOG_SRC,LOG_LEVEL,MEMO) values ('LOGGER.TEST','TRACE,DEBUG,INFO,WARN,ERROR',null);
Insert into LOGGER_LOG_CFG (LOG_SRC,LOG_LEVEL,MEMO) values ('LOGGER','WARN,ERROR',null);
Insert into LOGGER_LOG_CFG (LOG_SRC,LOG_LEVEL,MEMO) values ('*','ERROR',null);


/* MAIN PACKAGE WITH LOGGER */
CREATE OR REPLACE PACKAGE LOGGER 
IS 
   failure_in_forall   EXCEPTION; 
 
   PRAGMA EXCEPTION_INIT (failure_in_forall, -24381); 
  
   
   PROCEDURE error (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0);

   PROCEDURE warn (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0);

   PROCEDURE info (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0);

   PROCEDURE debug (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0);

   PROCEDURE trace (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0);   
   
   PROCEDURE test;
   
END;
/

create or replace PACKAGE BODY LOGGER 
IS 
    vn_debug_mode NUMBER :=0; /* enable: 1 , disable: 0*/
    vn_dbms_output_mode NUMBER :=1; /* enable: 1 , disable: 0*/

   PROCEDURE log_add (p_level IN VARCHAR2, p_app_info_in IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0) 
   IS 
      PRAGMA AUTONOMOUS_TRANSACTION; 
      /* Cannot call this function directly in SQL */ 
      c_code   CONSTANT INTEGER := SQLCODE; 
      v_log_line VARCHAR(500) := '';
      v_package_name VARCHAR(500) := '*';
      v_log_line_num NUMBER:= 0;
      v_enabled NUMBER:=0;

   BEGIN 

        v_log_line := utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(3) ); -- prima riga del chiamante al log
        v_log_line_num := utl_call_stack.unit_line(3);
        v_package_name:= substr(v_log_line,1, instr(v_log_line,'.',1)-1);
        
        --SOME DEBUG
        IF vn_debug_mode = 1 THEN 
            DBMS_OUTPUT.put_line ( ' v_log_line:  ' || v_log_line);
            DBMS_OUTPUT.put_line ( ' v_package_name:  ' || v_package_name);
        END IF;
        
        IF v_package_name is NULL or v_package_name = ''  THEN
            DBMS_OUTPUT.put_line ( ' v_package_name empty for ' || v_log_line);
            v_package_name := v_log_line;
        END IF;
        
        IF v_package_name is NULL or v_package_name = ''  THEN
            DBMS_OUTPUT.put_line ( ' v_package_name empty for ' || v_log_line);
            v_package_name := '*';
        END IF;
        
        BEGIN
            SELECT distinct 1 into v_enabled FROM LOGGER_LOG_CFG t WHERE 
            (UPPER(t.log_src) = UPPER(v_log_line)  AND LOG_LEVEL like '%'||p_level||'%')
            OR (UPPER(t.log_src) = UPPER(v_package_name) AND LOG_LEVEL like '%'||p_level||'%')
            OR (t.log_src = '*'  AND LOG_LEVEL like '%'||p_level||'%');
        EXCEPTION 
        WHEN no_data_found THEN 
            v_enabled := 0;
            DBMS_OUTPUT.put_line ( ' NO CONFIGURATION FOR ' || v_package_name || ', Error: ' || SQLCODE ||' -> ' || SQLERRM );
        WHEN OTHERS THEN
            DBMS_OUTPUT.put_line ( ' EXCEPTION WHEN OTHERS ' || v_package_name || ', Error: ' || SQLCODE ||' -> ' || SQLERRM );
            v_enabled :=0;
        END;

        
		--SOME DEBUG
        IF vn_debug_mode = 1 THEN 
            DBMS_OUTPUT.put_line ( 'LexDepth Depth LineNo Name');
            DBMS_OUTPUT.put_line ( '-------- ----- ------ ----');
            dbms_output.put_line(rpad(utl_call_stack.lexical_depth(utl_call_stack.dynamic_depth ()),9)
                || rpad(utl_call_stack.dynamic_depth (),5)
                || rpad(TO_CHAR(utl_call_stack.unit_line(utl_call_stack.dynamic_depth ())),8)
                || utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(utl_call_stack.dynamic_depth ()) ) );   
            DBMS_OUTPUT.put_line ( '-------- ----- ------ ----');
            DBMS_OUTPUT.put_line ( '-------- ----- ------ ----');
            FOR the_depth IN 1..utl_call_stack.dynamic_depth () LOOP
                dbms_output.put_line(rpad(utl_call_stack.lexical_depth(the_depth),9)
                || rpad(the_depth,5)
                || rpad(TO_CHAR(utl_call_stack.unit_line(the_depth),'999'),8)
                || utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(the_depth) ) );    
            END LOOP;
        END IF;


        IF v_enabled != 1 THEN /* WHEN LOG IS NOT ENABLED */
            --DBMS_OUTPUT.put_line ( 'v_enabled <> 1' || p_level);
            RETURN;
        END IF;

        IF vn_dbms_output_mode = 1 THEN 
            DBMS_OUTPUT.put_line ('LOG: [' || p_level || '] ' || p_app_info_in);
        END IF;
        
        BEGIN
        INSERT INTO LOGGER_LOG (
            log_sid,
            log_audsid,
            log_level,
            log_line,
            log_line_num,
            log_timestamp,         
            created_by, 
            start_time_trace_num,
            end_time_trace_num,
            errorcode, 
            callstack, 
            errorstack, 
            backtrace, 
            log_info
        ) VALUES (
            SYS_CONTEXT ('USERENV', 'SID'),
            SYS_CONTEXT ('USERENV', 'SESSIONID'),
            p_level,   
            v_log_line,
            v_log_line_num,
            SYSTIMESTAMP, 
            USER,
            p_start_time_trace_num,
            p_end_time_trace_num,                    
            c_code, 
            substr(DBMS_UTILITY.format_call_stack,1,least(3999,length(DBMS_UTILITY.format_call_stack))), 
            substr(DBMS_UTILITY.format_error_stack,1,least(3999,length(DBMS_UTILITY.format_error_stack))),            
            substr(DBMS_UTILITY.format_error_backtrace,1,least(3999,length(DBMS_UTILITY.format_error_backtrace))), 
            substr(p_app_info_in,1,least(3999,length(p_app_info_in))) 
            ); 
        EXCEPTION 
        WHEN OTHERS THEN            
            DBMS_OUTPUT.put_line ('Errore: ' || SQLCODE ||' -> ' || SQLERRM );
        END;
      COMMIT; 
   END; 


   PROCEDURE error (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0)
   IS
   BEGIN
      log_add ('ERROR', p_log_text, p_start_time_trace_num, p_end_time_trace_num);
   END;

   PROCEDURE warn (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0)
   IS
   BEGIN
      log_add ('WARN', p_log_text, p_start_time_trace_num, p_end_time_trace_num);
   END;


   PROCEDURE info (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0)
   IS
   BEGIN
      log_add ('INFO', p_log_text, p_start_time_trace_num, p_end_time_trace_num);
   END;


   PROCEDURE debug (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0)
   IS
   BEGIN
      log_add ('DEBUG', p_log_text, p_start_time_trace_num, p_end_time_trace_num);
   END;


   PROCEDURE trace (p_log_text IN VARCHAR2, p_start_time_trace_num NUMBER default 0, p_end_time_trace_num NUMBER default 0)
   IS
   BEGIN
      log_add ('TRACE', p_log_text, p_start_time_trace_num, p_end_time_trace_num);
   END;


	/* SOME TEST UNIT */
    PROCEDURE test_level_2 IS
    BEGIN
        dbms_output.put_line('Program Line = ' || $$plsql_line);
        dbms_output.put_line('Program Unit = ' || $$plsql_unit);  

        DBMS_OUTPUT.put_line ( 'LexDepth Depth LineNo Name');
        DBMS_OUTPUT.put_line ( '-------- ----- ------ ----');
        FOR the_depth IN REVERSE 1..utl_call_stack.dynamic_depth () LOOP
            dbms_output.put_line(rpad(utl_call_stack.lexical_depth(the_depth),9)
            || rpad(the_depth,5)
            || rpad(TO_CHAR(utl_call_stack.unit_line(the_depth)),8)
            || utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(the_depth) ) );
        END LOOP;        

        LOGGER.error('test L2 error...');       
        LOGGER.warn('test L2 warn...');
        LOGGER.info('test L2 info...');
        LOGGER.debug('test L2 debug...');
        LOGGER.trace('test L2 trace...');
    END;

    PROCEDURE test_level_1 IS
    BEGIN


        LOGGER.error('test L1 error...');       
        LOGGER.warn('test L1 warn...');
        LOGGER.info('test L1 info...');
        LOGGER.debug('test L1 debug...');
        LOGGER.trace('test L1 trace...');
        test_level_2;

    END;

    PROCEDURE test IS
    BEGIN
        LOGGER.error('test error...');       
        LOGGER.warn('test warn...');
        LOGGER.info('test info...');
        LOGGER.debug('test debug...');
        LOGGER.trace('test trace...');
        test_level_1;
    END;
END;
/


/*
TEST ON PACKAGE
*/
BEGIN
  LOGGER.TEST();
--rollback; 
END;
/

/*
CREATE TEST ON PROCEDURE
*/
CREATE OR REPLACE PROCEDURE LOGGER_TEST_PROCEDURE AS 
BEGIN
  LOGGER.error('LOGGER_TEST_PROCEDURE error...');  
  LOGGER.info('LOGGER_TEST_PROCEDURE info...');  
END LOGGER_TEST_PROCEDURE;
/

/*
TEST ON PROCEDURE
*/
BEGIN
  LOGGER_TEST_PROCEDURE();
--rollback; 
END;
