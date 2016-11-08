<html>
<head>
<title>KubeCon keynote demo</title>
<link href="https://fonts.googleapis.com/css?family=Roboto:400,500,700,400italic|Material+Icons" rel="stylesheet">
<style>
* { font-family: Roboto; }
</style>
</head>
<body>
<?php
$color = "green";
if($color == "blue") {
    $hex = "#2196F3";
} else if($color == "green") {
    $hex = "#4CAF50";
}
?>
<div style="padding:1em; background-color: <?=$hex?>; color:white; text-align:center;">Hello, world! I am the <?=$color?> version, running in container <?=`hostname`?> in <?=json_decode(file_get_contents("http://freegeoip.net/json"))->country_name;?>.</div>
<form action="/" method="POST">
<p>Word: <input type="text" name="word"></p>
<input type="submit">
</form>
<?php
$dbconn = pg_connect("host=psql dbname=testdb user=testuser password=password");
if($_POST["word"]) {
    pg_query("insert into hello (word) values (".pg_escape_literal($_POST["word"]).")");
    ?>DONE<?
}
print pg_last_error();
$result = pg_query("select word from hello");
?><ul><?
while ($line = pg_fetch_array($result, null, PGSQL_ASSOC)) {
    ?><li><?=$line["word"]?></li><?
}
?></ul>
</body>
</html>
