#!/bin/bash

###
# Инициализируем бд
###

# Подключитесь к серверу конфигурации и сделайте инициализацию:

docker compose exec -T configSrv mongosh --port 27017 <<EOF

rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
quit(); 
EOF

# Инициализируйте шарды:

docker compose exec -T shard1 mongosh --port 27018 <<EOF

rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
       // { _id : 1, host : "shard2:27019" }
      ]
    }
);
quit(); 
EOF

docker compose exec -T shard2 mongosh --port 27019 <<EOF

rs.initiate(
    {
      _id : "shard2",
      members: [
       // { _id : 0, host : "shard1:27018" },
        { _id : 1, host : "shard2:27019" }
      ]
    }
);
quit(); 
EOF

# Инцициализируйте роутер и наполните его тестовыми данными:

docker compose exec -T mongos_router mongosh --port 27020 <<EOF

sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

db.helloDoc.countDocuments() 
quit(); 
EOF

# Проверка на первом шарде:
docker compose exec -T shard1 mongosh --port 27018 -quiet <<EOF
use somedb
db.helloDoc.countDocuments();
quit(); 
EOF

# Проверка на втором шарде:
docker compose exec -T shard2 mongosh --port 27019 -quiet <<EOF
use somedb
db.helloDoc.countDocuments();
quit(); 
EOF

