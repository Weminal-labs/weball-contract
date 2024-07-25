# How to use this contract

### 1. clone the repo
```
https://github.com/weminal-labs/weball-contract.git
```

### 2. cd weball-contract

### 3. init your aptos address
make sure that aptos cli & aptos installed

```
aptos init --profile <your_profile_name>
```

### 4. config your address
in your Move.toml, add your wallet to admin 
admin = "your_address"

### 5. build file
```
aptos move compile
```

### 6. deploy the contract
```
aptos move publish --profile <your_profile_name>
```

### 7. after deploy contract, you gotta init contract
```
aptos move run --function-id <your_address_deployed>::gamev3::init_contract --profile <your_profile_name>
```

### 8. call the functions

#### create a new room:
```
aptos move run --function-id <your_address_deployed>::gamev3::create_room --args string:<room name> u64:<amount in Octacs> --profile <your_profile_name>
```
example data:
```
[
  {
    "bet_amount": "1",
    "create_time": "1721921542",
    "creator": "0x29c328d0e7cb0ee03ee1a786cda4cf740576ef39c8ca53363c7dd622a5af4622",
    "creator_ready": true,
    "is_creator_joined": true,
    "is_player2_joined": false,
    "is_player2_ready": false,
    "is_room_close": false,
    "player2": {
      "vec": []
    },
    "room_id": "1721921542",
    "room_name": "Room001",
    "winner": {
      "vec": []
    }
  }
]
```

#### init player:
```
aptos move run --function-id <your_address_deployed>::gamev3::create_account --args string:<name player> string:<img_link> string:<social_link> --profile <your_profile_name>
```

#### player02 join in a room:
```
aptos move run --function-id <your_address_deployed>::gamev3::join_room_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### player02 ready in a room:
```
aptos move run --function-id <your_address_deployed>::gamev3::ready_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### creator leave the room (can only leave when nobody joins room):
```
aptos move run --function-id <your_address_deployed>::gamev3::leave_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### player2 leave the room (can only leave when is_player2_ready = false):
```
aptos move run --function-id <your_address_deployed>::gamev3::leave_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### claim refund their apt back after leave the room:

#### creator leave the room (only leave when nobody joins room):
```
aptos move run --function-id <your_address_deployed>::gamev3::claim_reward --profile <your_profile_name>
```

#### pick winner (only admin can call this func):
```
aptos move run --function-id <your_address_deployed>::gamev3::pick_winner_and_transfer_bet --args u64:<room_id> address:<address_winner>  --profile <your_profile_name>
```

### 9. view the functions

#### get_all_rooms to see all rooms created

#### get_player_info to see player info (get issue now, updating...)

#### room_detail_by_room_id
example data:
```
0x29c328d0e7cb0ee03ee1a786cda4cf740576ef39c8ca53363c7dd622a5af4622
1721921542
Room001
1721921542
1
true
true
false
{
  "vec": []
}
false
false
{
  "vec": []
}
```
