CREATE EVENT SESSION [QueriesOver_1Second] ON DATABASE 
ADD EVENT sqlserver.module_end(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000))),
ADD EVENT sqlserver.rpc_completed(SET collect_output_parameters=(1),collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.num_response_rows,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000)))
ADD TARGET package0.ring_buffer(SET max_events_limit=(1000),max_memory=(2048))
WITH (MAX_MEMORY=2048 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO
