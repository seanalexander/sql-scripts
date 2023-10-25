:setvar EnvironmentName "environment-name-should-be-the-container-name-and-follow-its-rules"
:setvar StorageAccountName "storageaaccountname.blob.core.windows.net"
:setvar DatabaseName "DatabaseNameHere"
/*All Containers*/
:setVar SharedAccessSignature "sv=2021-10-04&ss=b&srt=co&st=2023-02-16T14%3A57%3A46Z&se=2025-02-17T14%3A57%3A00Z&sp=rwlacu&sig=signaturehere"

CREATE DATABASE SCOPED CREDENTIAL [https://storageaaccountname.blob.core.windows.net/$(EnvironmentName)]
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = '$(SharedAccessSignature)';

/*
Search and replace all instances of
ALL_QUERIES_FROM_THIS_SERVERNAME_ALSO
and
ALL_QUERIES_FROM_THIS_SERVERNAME

with the one or two servers you want to capture all queries from.
*/

CREATE EVENT SESSION [$(EnvironmentName)ALL_QUERIES_FROM_THIS_SERVERNAME] ON DATABASE 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME')) OR [sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME_ALSO'))),
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME')) OR [sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME_ALSO'))),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME')) OR [sqlserver].[equal_i_sql_unicode_string]([sqlserver].[client_hostname],N'ALL_QUERIES_FROM_THIS_SERVERNAME_ALSO')))
ADD TARGET package0.event_file(SET filename=N'https://$(StorageAccountName)/$(EnvironmentName)/$(DatabaseName)_$(EnvironmentName)ALL_QUERIES_FROM_THIS_SERVERNAME.xel',max_file_size=(128)),
ADD TARGET package0.ring_buffer(SET max_memory=(4096))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO

CREATE EVENT SESSION [Error_reported] ON DATABASE 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.sql_text,sqlserver.tsql_stack)
    WHERE ([severity]>(10)))
ADD TARGET package0.event_file(SET filename=N'https://$(StorageAccountName)/$(EnvironmentName)/$(DatabaseName)_Error_reported.xel',max_file_size=(128)),
ADD TARGET package0.ring_buffer(SET max_memory=(4096))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

CREATE EVENT SESSION [QueriesOverOneSecond_Loop] ON DATABASE 
ADD EVENT sqlserver.module_end(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000))),
ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000))),
ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash_signed,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([duration]>=(1000000)))
ADD TARGET package0.event_file(SET filename=N'https://$(StorageAccountName)/$(EnvironmentName)/$(DatabaseName)_QueriesOverOneSecond_Loop.xel',max_file_size=(128)),
ADD TARGET package0.ring_buffer(SET max_memory=(4096))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO

--We don't start the All Queries extended event unless done manually.
/*
ALTER EVENT SESSION [$(EnvironmentName)ALL_QUERIES_FROM_THIS_SERVERNAME]  
ON DATABASE  
STATE = start;  
GO
*/  


ALTER EVENT SESSION [Error_reported]  
ON DATABASE  
STATE = start;  
GO  

ALTER EVENT SESSION [QueriesOverOneSecond_Loop]  
ON DATABASE  
STATE = start;  
GO  
