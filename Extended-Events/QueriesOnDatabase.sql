:setvar Hostname "your-laptop-name"
:setvar DatabaseName "your-database-name"
:setvar MinQueryDurationNano "1000"

CREATE EVENT SESSION [QueriesOnDatabase_$(DatabaseName)_$(Hostname)] ON SERVER 
ADD EVENT sqlserver.module_end(
    ACTION(sqlos.task_time,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [package0].[greater_than_equal_uint64]([duration],($(MinQueryDurationNano))) AND [sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'$(DatabaseName)') AND [sqlserver].[client_hostname]=N'$(Hostname)')),
ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
    ACTION(sqlos.task_time,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [package0].[greater_than_equal_uint64]([duration],($(MinQueryDurationNano))) AND [sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'$(DatabaseName)') AND [sqlserver].[client_hostname]=N'$(Hostname)'))
ADD TARGET package0.event_file(SET filename=N'D:\QueriesOnDatabase_$(DatabaseName)_$(Hostname).xel',max_file_size=(256),max_rollover_files=(10))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
