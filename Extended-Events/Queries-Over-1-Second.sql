USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Extended Events - Capture Queries over 1 Second', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'This scheduled job will start and stop an Extended Events Session which captures any queries over 1 second in duration.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Extended Events - Capture Queries over 1 Second', @server_name = N'SQLServerName'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'Extended Events - Capture Queries over 1 Second', @step_name=N'Create Extended Events and Shut Off Previous', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @ExtendedEvents_FilePath VARCHAR(100) = ''C:\temp\Traces''

DECLARE @Date_Today DATE = GETDATE()
DECLARE @Date_Yesterday DATE = DATEADD(dd, -1, @Date_Today)
DECLARE @Datestring_Yesterday VARCHAR(10) = CAST(YEAR(@Date_Yesterday) AS VARCHAR(4)) + ''_'' + RIGHT(''0'' + CAST(MONTH(@Date_Yesterday) AS VARCHAR(2)),2) + ''_'' + RIGHT(''0'' + CAST(DAY(@Date_Yesterday) AS VARCHAR(2)),2)
DECLARE @Datestring_Today VARCHAR(10) = CAST(YEAR(@Date_Today) AS VARCHAR(4)) + ''_'' + RIGHT(''0'' + CAST(MONTH(@Date_Today) AS VARCHAR(2)),2) + ''_'' + RIGHT(''0'' + CAST(DAY(@Date_Today) AS VARCHAR(2)),2)

DECLARE @ExtendedEventsName_Suffix VARCHAR(50) = ''QueriesOverOneSecond''
DECLARE @ExtendedEventsName_Yesterday VARCHAR(255) = @Datestring_Yesterday + ''_'' + @ExtendedEventsName_Suffix
DECLARE @ExtendedEventsName_Today VARCHAR(255) = @Datestring_Today + ''_'' + @ExtendedEventsName_Suffix

DECLARE @Exec_CreateEventSession VARCHAR(4000) = ''
CREATE EVENT SESSION [''+@ExtendedEventsName_Today+''] ON SERVER 
ADD EVENT sqlserver.module_end(
    ACTION(sqlos.task_time,sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.database_name)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000))),
ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
    ACTION(sqlos.task_time,sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.database_name)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [duration]>=(1000000))) 
ADD TARGET package0.event_file(SET filename=N'''''' + @ExtendedEvents_FilePath + ''\''+@ExtendedEventsName_Today+''.xel'''',max_file_size=(256),max_rollover_files=(10))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
''

DECLARE @Exec_StartNewSession VARCHAR(4000) = ''ALTER EVENT SESSION [''+@ExtendedEventsName_Today+''] ON SERVER STATE = START;''

DECLARE @Exec_DropOldSession VARCHAR(4000) = ''ALTER EVENT SESSION [''+@ExtendedEventsName_Yesterday+''] ON SERVER STATE = STOP;
DROP EVENT SESSION [''+@ExtendedEventsName_Yesterday+''] ON SERVER
''

EXEC (@Exec_CreateEventSession)
EXEC (@Exec_StartNewSession)
EXEC (@Exec_DropOldSession)
', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'Extended Events - Capture Queries over 1 Second', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'This scheduled job will start and stop an Extended Events Session which captures any queries over 1 second in duration.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Extended Events - Capture Queries over 1 Second', @name=N'Run At Mightnight', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190101, 
		@active_end_date=99991231, 
		@active_start_time=100, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
