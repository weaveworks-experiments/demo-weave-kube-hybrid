<?php
$dbconn = pg_connect("host=psql dbname=testdb user=testuser password=password");
//pg_query("create database words");
//$dbconn = pg_connect("host=psql dbname=words user=testuser password=password");
pg_query("create table hello (word text)");
