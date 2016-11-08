#!/bin/bash
docker build -t lmarsden/demo-app:green .
sed -i "" 's/ = "green"/ = "blue"/' index.php
docker build -t lmarsden/demo-app:blue .
sed -i "" 's/ = "blue"/ = "green"/' index.php
docker push lmarsden/demo-app:green
docker push lmarsden/demo-app:blue
