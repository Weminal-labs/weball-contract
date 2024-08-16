# Smart Contract Specifications

### 1. Involved Actors.

Player: Users who interact with the contract by creating rooms, joining rooms, sending messages, etc.

Admin: The owner or controller of the contract who has special permissions, such as picking a winner and transferring the bet amount.

### 2. Internal Methods:
`create_room`: Allows a player to create a new room with specific parameters.

`join_room_by_room_id`: Allows a player to join a room by providing the room ID.

`ready_by_room_id`: Marks a player as ready in a room.

`leave_room`: Allows a player to leave a room (creator can only leave when nobody joined && player2 can only leave when field is_player2_ready = false).

`pick_winner_and_transfer_bet`: Allows ADMIN Game to pick a winner and transfer the bet amount after game end.

`send_global_chat_message`: Allows a player to send a message to the global chat.

`send_chat_to_room_id`: Allows a player to send a message to a specific room.

`update_account`: Updates a player's account information (name and username).

`give_like_account`: Allows a player to like another player's account.

`give_dislike_account`: Allows a player to dislike another player's account.

#### Creating a Room:
```
aptos move run --function-id <your_address_deployed>::gamev3::create_room --args string:<room name> u64:<amount in Octas> --profile <your_profile_name>
```

#### Giving a Like to an Account:
```
aptos move run --function-id <your_address_deployed>::gamev3::give_like_account --args address:<liked_address> --profile <your_profile_name>
```

#### Giving a Dislike to an Account:
```
aptos move run --function-id <your_address_deployed>::gamev3::give_dislike_account --args address:<disliked_address> --profile <your_profile_name>
```

#### Leaving a Room:
```
aptos move run --function-id <your_address_deployed>::gamev3::leave_room --args u64:<room_id> --profile <your_profile_name>
```

#### Joining a Room by ID:
```
aptos move run --function-id <your_address_deployed>::gamev3::join_room_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### Marking Ready in a Room:
```
aptos move run --function-id <your_address_deployed>::gamev3::ready_by_room_id --args u64:<room_id> --profile <your_profile_name>
```

#### Sending a Message to a Room:
```
aptos move run --function-id <your_address_deployed>::gamev3::send_message_room_id --args u64:<room_id> string:<message> --profile <your_profile_name>
```

#### Sending a Global Chat Message:
```
aptos move run --function-id <your_address_deployed>::gamev3::send_global_chat_message --args string:<message> --profile <your_profile_name>
```

#### Updating a Player's Account:
```
aptos move run --function-id <your_address_deployed>::gamev3::update_account --args string:<new_name> string:<new_username> --profile <your_profile_name>
```

### 3. External Methods:
#### get_all_rooms: Retrieves all the created rooms.
#### get_chat_messages: Retrieves chat messages for a specific room.
#### get_global_chat_messages: Retrieves global chat messages.
#### get_player_info: Retrieves detailed information about a player.
#### get_player_tickets: Retrieves a player's tickets.
#### get_player_username: Retrieves a player's username.
#### get_room_now: Retrieves the current room in which a player is present.
#### get_top_100_players: Retrieves the top 100 players with the highest points, including fields for games played and winning games.
#### get_top_10_players: Retrieves the top 10 players.
#### get_top_50_players: Retrieves the top 50 players.
#### get_waiting_rooms: Retrieves rooms waiting for players to join.
#### is_username_taken: Checks whether a specific username is already taken.
#### room_detail_by_room_id: Retrieves detailed information for a specific room by room ID.
#### search_rooms: Searches for rooms based on a search term.

### Table:
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




