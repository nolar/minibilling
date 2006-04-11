create table `account` (
	`account`	integer unsigned	not null auto_increment,
	`logname`	varchar(255)		    null ,
	`password`	varchar(255)		    null ,
	`vname`		varchar(255)		    null ,
	`fname`		varchar(255)		    null ,
	`sname`		varchar(255)		    null ,
	`tname`		varchar(255)		    null ,
	`email`		varchar(255)		    null ,
	primary key			(`account`)
) engine=innodb default charset=ucs2;

create table `address` (
	`address`	integer unsigned	not null auto_increment,
	`account`	integer unsigned	not null references `account` (`account`) on delete cascade on update cascade,
	`actual_from`	datetime		    null ,
	`actual_till`	datetime		    null ,
	`ipv4address`	integer unsigned	not null default 0,
	`ipv4masklen`	integer unsigned	not null default 32,
	`ipv4_from`	integer unsigned	    null /* calculated  */,
	`ipv4_till`	integer unsigned	    null /* calculated */,
	index `index_account`		(`account`    ),
	index `index_actual_from`	(`actual_from`),
	index `index_actual_till`	(`actual_till`),
	index `index_ipv4address`	(`ipv4address`),
	index `index_ipv4masklen`	(`ipv4masklen`),
	index `index_ipv4_from`		(`ipv4_from`  ),
	index `index_ipv4_till`		(`ipv4_till`  ),
	primary key			(`address`    )
) engine=innodb default charset=ucs2;

create table catcher (
	id		integer unsigned not null auto_increment,
	account		integer unsigned not null references account(id) on delete cascade on update cascade,
	stamp_from	datetime null,
	stamp_till	datetime null,
	quantum		integer unsigned not null,
	primary key (id)
) engine=innodb;

create table catched (
	catcher		integer unsigned not null references catcher(id)
				on delete cascade on update cascade,
	stamp		datetime not null,
	bytes		integer not null default 0,
	packets		integer not null default 0,
	primary key (catcher, stamp)
) engine=innodb;

create table traffic (
	protocol	integer unsigned not null,
	src_addr	integer unsigned not null,
	dst_addr	integer unsigned not null,
	src_port	integer unsigned not null,
	dst_port	integer unsigned not null,
	bytes		integer unsigned not null,
	packets		integer unsigned not null,
	stamp		datetime         not null,
	src		integer unsigned null references address(id) on delete set null on update cascade,
	dst		integer unsigned null references address(id) on delete set null on update cascade,
	handled		bit not null default 0,
	index idx_stamp		(stamp),
	index idx_handled	(handled)
) engine=innodb;

alter table `traffic` add column `src` integer unsigned null references `address` (`address`) on delete set null on update cascade;
alter table `traffic` add column `dst` integer unsigned null references `address` (`address`) on delete set null on update cascade;
alter table `traffic` add column `handled` bit not null default 0;
create index `index_handled` on `traffic` (`handled`);

insert into `account` (`logname`, `vname`) values
	('*inet'	, 'Internet'			),
	('*router'	, 'Router (numeri.net)'		),
	('*internal'	, 'Internal LAN'		),
	('*kraslan'	, 'ISP KrasLan'			),
	('*xl'		, 'ISP XL'			),

	('nolar'	, 'Computer NOLA'		);
	
insert into `address` (`account`, `ipv4address`, `ipv4masklen`, `actual_from`, `actual_till`) values
	((select `account` from `account` where `logname`='*inet'	), 0				 ,  0, null, null),
	((select `account` from `account` where `logname`='*router'	), inet_aton('10.0.0.254'	), 32, null, null),
	((select `account` from `account` where `logname`='*router'	), inet_aton('87.236.41.3'	), 32, null, null),
	((select `account` from `account` where `logname`='*internal'	), inet_aton('10.0.0.0'		), 24, null, null),
	((select `account` from `account` where `logname`='*kraslan'	), inet_aton('10.10.0.0'	), 16, null, null),
	((select `account` from `account` where `logname`='*kraslan'	), inet_aton('192.168.0.0'	), 16, null, null),
	((select `account` from `account` where `logname`='*kraslan'	), inet_aton('87.236.40.0'	), 24, null, null),
	((select `account` from `account` where `logname`='*kraslan'	), inet_aton('87.236.41.0'	), 24, null, null),
	((select `account` from `account` where `logname`='*xl'		), inet_aton('87.236.41.246'	), 32, null, null),
	((select `account` from `account` where `logname`='*xl'		), inet_aton('87.236.42.0'	), 24, null, null),
	((select `account` from `account` where `logname`='nolar'	), inet_aton('10.0.0.1'		), 32, null, null);

/* правка таблицы адресов для корректной работы */
update `address` set
	`ipv4_from` = `ipv4address` - `ipv4address` % pow(2,32-`ipv4masklen`),
	`ipv4_till` = `ipv4address` - `ipv4address` % pow(2,32-`ipv4masklen`) + (pow(2,32)-1) % pow(2,32-`ipv4masklen`);

/* обработка трафика: поиск владельца пакета по источнику */
	update `traffic` set `src` = (
			select `address` from `address`
			 where (`traffic`.`srchost` between `ipv4_from` and `ipv4_till`)
			   and (`actual_from` is null or `actual_from` <= `traffic`.`started`)
			   and (`actual_till` is null or `actual_till` >  `traffic`.`started`)
			 order by `ipv4masklen` desc limit 1)
		where `src` is null;
	update `traffic` set `dst` = (
			select `address` from `address`
			 where (`traffic`.`dsthost` between `ipv4_from` and `ipv4_till`)
			   and (`actual_from` is null or `actual_from` <= `traffic`.`started`)
			   and (`actual_till` is null or `actual_till` >  `traffic`.`started`)
			 order by `ipv4masklen` desc limit 1)
		where `dst` is null;

select inet_ntoa(`srchost`),`src`,`logname`,`vname` from `traffic`
	join `address` on `traffic`.`src`=`address`.`address`
	join `account` on `address`.`account`=`account`.`account`
 where `src` is not null order by 3,1;

select `vname`, sum(`bytes`) from `traffic`
	join `address` on `traffic`.`src`=`address`.`address`
	join `account` on `address`.`account`=`account`.`account`
 where `src` is not null and `direction` > 0
 group by `vname`;

select src_addr,dst_addr,src,dst from traffic where src is not null;
select src_addr,dst_addr,src,dst from traffic where dst is not null;



/* выявление адресов, которые пересекаются с временным интервалом [F..T), F<=T */
set @F='2004-11-20 23:59:59';
set @T='2004-11-20 23:59:59';
select * from address
	where (stamp_from is null or stamp_from<@T or stamp_from=@F)
	  and (stamp_till is null or stamp_till>@F);

/* выявление адресов, пересекающихся с A на временном интервале [F..T) */
set @A='10.10.2.1';
set @F='2004-11-20 23:59:59';
set @T='2004-11-20 23:59:59';
select B.* from address A, address B
	where A.address=@A
	and (A.stamp_from is null or A.stamp_from<@T or A.stamp_from=@F)
	and (A.stamp_till is null or A.stamp_till>@F)
	and (B.stamp_from is null or B.stamp_from<A.stamp_till or B.stamp_from=A.stamp_from)
	and (B.stamp_till is null or B.stamp_till>A.stamp_from);

/* выявление всех диапазонов, которым принадлежит адрес A */
set @A='10.0.0.10';
select * from address
	where	inet_aton(@A) >= ((inet_aton(address)-inet_aton(address)%pow(2,32-netmask))
	and	inet_aton(@A) <= ((inet_aton(address)-inet_aton(address)%pow(2,32-netmask)+(pow(2,32)-1)%pow(2,32-netmask));



/* определение кванта сумматора */
replace catched (catcher, stamp, bytes, packets)
	select AD.id,inet_ntoa(AD.address) as address,R.id,T.src
/*		R.id,
		from_unixtime(unix_timestamp(T.stamp)-unix_timestamp(T.stamp)%R.quantum),
		D.bytes + T.bytes,
		D.packets + T.packets */
	from address AD,catcher R,traffic T/*,catched D*/
	where	(AD.account = R.account) 
	and	(T.src is not null and T.src = AD.id)
;


/* выборка сколько байт закинуть на какие отловщики и в какие временные отрывки */
select R.id,from_unixtime(unix_timestamp(T.stamp)-unix_timestamp(T.stamp)%R.quantum) as q,
	sum(bytes),count(bytes),src
	from catcher R,traffic T,address A
	where T.src=A.id and A.account=R.account
	group by 2,1
	order by 1,2;


select R.id,from_unixtime(unix_timestamp(T.stamp)-unix_timestamp(T.stamp)%R.quantum) as q,
		sum(bytes), count(bytes)
 	from traffic  T, catcher R where src=2 and R.account=1 
	group by 2,1
	order by 1,2;
  
replace catched values		
	from traffic, catcher
	catcher	=
	stamp	=
	bytes	= bytes	+
	packets	= packets+

/* закидка трафика на сумматор */




