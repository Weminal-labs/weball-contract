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

`send_global_chat_message`: Allows a player to send a message to the global chat.

`send_chat_to_room_id`: Allows a player to send a message to a specific room.

`update_account`: Updates a player's account information (name and username).

`create_room_mate`: Creates a room with an invitation for a specific friend to join.

`add_friend`: Allows a player to add another player as a friend.

`give_like_account`: Allows a player to like another player's account.

`give_dislike_account`: Allows a player to dislike another player's account.

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

#### pick winner (only admin can call this func):
```
aptos move run --function-id <your_address_deployed>::gamev3::pick_winner_and_transfer_bet --args u64:<room_id> address:<address_winner>  --profile <your_profile_name>
```

#### Sending a Global Chat Message:
```
aptos move run --function-id <your_address_deployed>::gamev3::send_global_chat_message --args string:<message> --profile <your_profile_name>
```

#### Sending a Message to a Room:
```
aptos move run --function-id <your_address_deployed>::gamev3::send_chat_to_room_id --args u64:<room_id> string:<message> --profile <your_profile_name>
```

#### Updating Player Account:
```
aptos move run --function-id <your_address_deployed>::gamev3::update_account --args string:<new_name> string:<new_username> --profile <your_profile_name>
```

#### Creating a Room with a Friend:
```
aptos move run --function-id <your_address_deployed>::gamev3::create_room_mate --args string:<room_name> u64:<bet_amount> string:<friend_username> --profile <your_profile_name>
```

#### Adding a Friend:
```
aptos move run --function-id <your_address_deployed>::gamev3::add_friend --args string:<friend_username> --profile <your_profile_name>
```

#### Liking a Player:
```
aptos move run --function-id <your_address_deployed>::gamev3::give_like_account --args address:<liked_address> --profile <your_profile_name>
```

#### Disliking a Player:
```
aptos move run --function-id <your_address_deployed>::gamev3::give_dislike_account --args address:<disliked_address> --profile <your_profile_name>
```

### 3. External Methods
#### get_all_rooms: Retrieves all created rooms.

#### get_player_info: Retrieves information about a player.

#### room_detail_by_room_id: Retrieves detailed information about a specific room.

#### get_top_100_players: Retrieves the top 100 players with the highest points, including their games played and winning games.
#### get_chat_messages: Retrieves chat messages for a specific room.
#### get_global_chat_messages: Retrieves global chat messages.
#### get_friend_list: Retrieves the friend list of a player.
#### get_room_now: Retrieves the current room a player is in.
#### get_player_username: Retrieves a player's username.
#### search_rooms: Searches for rooms based on a search term.

| Function                         | Parameters                                        | Description                           |
|----------------------------------|--------------------------------------------------|---------------------------------------|
| `create_room`                    | `&signer`, `0x1::string::String`, `u64`           | Creates a room with a name and bet amount. |
| `give_dislike_account`           | `&signer`, `address`                              | Dislikes a player's account.          |
| `give_like_account`              | `&signer`, `address`                              | Likes a player's account.             |
| `join_room_by_room_id`           | `&signer`, `u64`                                  | Joins a room by its ID.               |
| `leave_room`                     | `&signer`                                         | Leaves the room.                      |
| `pick_winner_and_transfer_bet`   | `&signer`, `u64`, `address`                       | Picks the winner and transfers the bet amount. |
| `ready_by_room_id`               | `&signer`, `u64`                                  | Marks a player as ready by room ID.   |
| `send_chat_to_room_id`           | `&signer`, `u64`, `0x1::string::String`           | Sends a message to a specific room.   |
| `send_global_chat_message`       | `&signer`, `0x1::string::String`                  | Sends a message to the global chat.   |
| `send_message_room_id`           | `&signer`, `u64`, `0x1::string::String`           | Sends a message to a room by its ID.  |
| `update_account`                 | `&signer`, `0x1::string::String`, `0x1::string::String`, `0x1::string::String` | Updates a player's account information (name, username, etc.). |




