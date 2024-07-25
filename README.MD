# Smart Contract Specifications

### 1. Involved Actors.

Player: Users who interact with the contract by create room, joining rooms,...

Admin: The owner or controller of the contract who has special permissions, like picking a winner.

### 2. Internal Methods:
`create_room`: Allows a player to create a new room with specific parameters.

`create_account`: Registers a new player with the contract to store point, game_played, winning_games.

`join_room_by_room_id`: Allows a player to join a room by providing the room ID.

`ready_by_room_id`: Marks a player as ready in a room.

`leave_by_room_id`: Allows a player to leave a room (creator can only leave when nobody joined && player2 can only leave when field is_player2_ready = false).

`claim_reward`: Allows players to claim their refund after leaving a room.

`pick_winner_and_transfer_bet`: Allows ADMIN Game to pick a winner and transfer the bet amount after game end.


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

### 3. External Methods
#### get_all_rooms: Retrieves all created rooms.

#### get_player_info: Retrieves information about a player.

#### room_detail_by_room_id: Retrieves detailed information about a specific room.
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
