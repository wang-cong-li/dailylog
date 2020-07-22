create database druid_log;
use druid_log;
create table druid_log_file (
	id int primary key auto_increment;
	file_path varchar(256) not null;
	file_name varchar(128) not null;
	push_begin_time timestamp not null default current_timestamp;
	push_end_time timestamp not null default current_timestamp;
	push_result tinyint not null default 0;
	push_result_raw_json varchar(512);
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4