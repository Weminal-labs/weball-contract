module admin::gamev3 {
    // === Imports ===
   use std::string::{Self, String, sub_string};
   use aptos_std::simple_map::{Self, SimpleMap};
   use std::signer;
   use std::vector;
   use aptos_framework::coin;
   use aptos_framework::aptos_coin::{AptosCoin};
   use aptos_framework::event::{EventHandle, emit_event};
   use aptos_framework::timestamp;
   use aptos_framework::account;
   use std::option::{Option, Self};

    // === Errors ===
   //errors handling
   const E_ROOM_NOT_FOUND: u64 = 1001;
   const E_PLAYER_ALREADY_READY: u64 = 1002;
   const E_PLAYER_ACCOUNTS_NOT_EXIST: u64 = 1003;
   const E_PLAYER_ACCOUNT_NOT_FOUND: u64 = 1004;
   const E_NOT_AUTHORIZED: u64 = 1005;
   const E_PLAYER_ACCOUNT_NOT_EXIST: u64 = 1006;
   const E_INVALID_WINNER: u64 = 1007;
   const E_REFUND_POOL_NOT_EXIST: u64 = 1008;
   const E_USERNAME_ALREADY_EXISTS: u64 = 1009;
   const E_USERNAME_ALREADY_UPDATED: u64 = 1010;
   const E_PLAYER_ALREADY_IN_ACTIVE_ROOM: u64 = 1011;
   const E_CANNOT_LIKE_SELF: u64 = 1012;
   const E_CANNOT_DISLIKE_SELF: u64 = 1013;
   const E_ALREADY_LIKED: u64 = 1014
   const E_ALREADY_DISLIKED: u64 = 1015;
   const E_CANNOT_ADD_SELF: u64 = 1016;
   const E_ALREADY_FRIENDS: u64 = 1017;
   const E_FRIEND_LIST_NOT_INITIALIZED: u64 = 1018;
   const E_NOT_FRIENDS: u64 = 1019;


    // === Constants ===

    // constants for default values
   const DEFAULT_NAME: vector<u8> = b"No_name";
   // const DEFAULT_IMAGE_LINK: vector<u8> = b"Image address not found";
   // const DEFAULT_HASH: vector<u8> = b"not found";
   const SEED: vector<u8> = b"REFUND_POOL_RESOURCE_ACCOUNT";

    // === Structs ===

   // struct to define a Room
   struct Room has key, store, copy, drop {
      creator: address,
      room_id: u64,
      room_name: String,
      create_time: u64,
      bet_amount: u64,
      is_creator_joined: bool,
      creator_ready: bool,
      is_player2_joined: bool,
      player2: Option<address>,
      is_player2_ready: bool,
      is_room_close: bool,
      winner: Option<address>,
      invited_friend_username: Option<String>,


   }

   // event for room creation
   struct RoomCreatedEvent has store, drop {
      creator: address,
      room_id: u64,
      room_name: String,
      bet_amount: u64,
   }

   // state management for rooms
   struct RoomState has key {
       rooms: vector<Room>,
       room_created_events: EventHandle<RoomCreatedEvent>,
       pools: vector<Pool>,
       admin_cap: account::SignerCapability,
       chats: SimpleMap<u64, vector<ChatMessage>>,
       global_chat: vector<GlobalChatMessage>,


   }

   //search value
   struct SearchResult has drop, store {
       room_id: u64,
       room_name: String,
       creator_username: String,
       player2_username: Option<String>,
       bet_amount: u64,
       is_room_close: bool,
   }

  //handle refund when creator or player leave the room
   struct Refund has store, drop {
       room_id: u64,
       player: address,
       amount: u64,
   }

  //chat global for players
   struct GlobalChatMessage has store, drop, copy {
       sender: address,
       message: String,
       timestamp: u64,
   }


   // struct to define player account
   struct PlayerAccount has key, store, drop, copy {
       name: String,
       username: String,
       address_id: address,
       points: u64,
       games_played: u64,
       winning_games: u64,
       has_updated_username: bool,
       likes_received: u64,
       dislikes_received: u64,
       liked_players: vector<address>,
       disliked_players: vector<address>,
   }

   //store top 100 player
   struct PlayerData has drop, store, copy {
       address: address,
       points: u64,
       games_played: u64,
       winning_games: u64,
   }

  //add friend
   struct FriendList has key {
       friends: vector<address>,
   }

  //chat in the room
   struct ChatMessage has store, drop, copy {
       sender: address,
       message: String,
       timestamp: u64,
   }

  // init room chat for room
   struct RoomChat has key {
       room_id: u64,
       messages: vector<ChatMessage>,
   }

   // resource to hold playeraccounts
   struct PlayerAccounts has key {
       accounts: vector<PlayerAccount>,
   }

   // create a pool when creator create a room or player2 join a room
   struct Pool has key, store, drop {
       room_id: u64,
       total_amount: u64,
   }

    // === Public-Mutative Functions ===

   // function to create a player account
   public fun create_account(
       signer: &signer,
       name: String,
   ) acquires PlayerAccounts {
       let account_address = signer::address_of(signer);
      
       let player_name = if (string::length(&name) > 0) {
           name
       } else {
           string::utf8(DEFAULT_NAME)
       };

       let current_time = timestamp::now_microseconds();
       let unique_username = string::utf8(b"NoName");
       string::append(&mut unique_username, u64_to_string(current_time));
       let player_account = PlayerAccount {
           name: player_name,
           username: unique_username,
           address_id: account_address,
           points: 0,
           games_played: 0,
           winning_games: 0,
           has_updated_username: false,
           likes_received: 0,
           dislikes_received: 0,
           liked_players: vector::empty<address>(),
           disliked_players: vector::empty<address>(),


       };

       // create PlayerAccount resource at the player's address
       move_to(signer, player_account);

       // also add to the global list
       let player_accounts = borrow_global_mut<PlayerAccounts>(@admin);
       vector::push_back(&mut player_accounts.accounts, player_account);
   }

   // function to create a new room with provided parameters
   public entry fun create_room(
       creator: &signer,
       room_name: String,
       bet_amount: u64
   ) acquires RoomState, PlayerAccounts {
       let creator_address = signer::address_of(creator);
       // check if the creator is already in active room
       assert!(!is_player_in_active_room(creator_address), E_PLAYER_ALREADY_IN_ACTIVE_ROOM);
       let current_time = timestamp::now_seconds();
       let bet_coin = coin::withdraw<AptosCoin>(creator, bet_amount);
       if (!exists<PlayerAccount>(creator_address)) {
           create_account(creator, string::utf8(DEFAULT_NAME));
       };


       let room = Room {
           creator: creator_address,
           room_id: current_time,
           room_name,
           create_time: current_time,
           bet_amount,
           is_creator_joined: true,
           creator_ready: true,
           is_player2_joined: false,
           player2: option::none<address>(),
           is_player2_ready: false,
           is_room_close: false,
           winner: option::none<address>(),
           invited_friend_username: option::none(),
       };

       let state = borrow_global_mut<RoomState>(@admin);
       vector::push_back(&mut state.rooms, room);

       // initialize chat for the new room
       simple_map::add(&mut state.chats, current_time, vector::empty<ChatMessage>());


       // create pool for the room
       let pool = Pool {
           room_id: current_time,
           total_amount: bet_amount,
       };
       vector::push_back(&mut state.pools, pool);


       let event = RoomCreatedEvent {
           creator: creator_address,
           room_id: current_time,
           room_name,
           bet_amount,
       };
       emit_event(&mut state.room_created_events, event);


       // deposit bet amount to admin account (representing the pool)
       coin::deposit(@admin, bet_coin);
   }


   public entry fun send_global_chat_message(
       sender: &signer,
       message: String
   ) acquires RoomState {
       let sender_address = signer::address_of(sender);
       let state = borrow_global_mut<RoomState>(@admin);
      
       let new_message = GlobalChatMessage {
           sender: sender_address,
           message,
           timestamp: timestamp::now_seconds(),
       };
      
       vector::push_back(&mut state.global_chat, new_message);
      
       // limit the chat to the last 100 messages
       if (vector::length(&state.global_chat) > 100) {
           vector::remove(&mut state.global_chat, 0);
       };
   }






  fun is_player_in_active_room(player_address: address): bool acquires RoomState {
     let state = borrow_global<RoomState>(@admin);
     let len = vector::length(&state.rooms);
     let i = 0;
  
  
     while (i < len) {
         let room = vector::borrow(&state.rooms, i);
         if (!room.is_room_close &&
             (room.creator == player_address ||
             (option::is_some(&room.player2) && *option::borrow(&room.player2) == player_address))) {
             return true
         };
         i = i + 1;
     };
  
  
     false
  }
  
  
  fun is_player_in_room(player_address: address, room_id: u64): bool acquires RoomState {
         let state = borrow_global<RoomState>(@admin);
         let len = vector::length(&state.rooms);
         let i = 0;
  
         while (i < len) {
             let room = vector::borrow(&state.rooms, i);
             if (room.room_id == room_id && !room.is_room_close &&
                 (room.creator == player_address ||
                 (option::is_some(&room.player2) && *option::borrow(&room.player2) == player_address))) {
                 return true
             };
             i = i + 1;
         };
  
  
         false
     }


   public entry fun send_chat_to_room_id(
       sender: &signer,
       room_id: u64,
       message: String
   ) acquires RoomState {
       let sender_address = signer::address_of(sender);
      
       // check if the sender is in the room
       assert!(is_player_in_room(sender_address, room_id), E_NOT_AUTHORIZED);


       let state = borrow_global_mut<RoomState>(@admin);
      
       // get the chat for the room
       assert!(simple_map::contains_key(&state.chats, &room_id), E_ROOM_NOT_FOUND);
       let chat = simple_map::borrow_mut(&mut state.chats, &room_id);


       // create and add the new message
       let new_message = ChatMessage {
           sender: sender_address,
           message,
           timestamp: timestamp::now_seconds(),
       };
       vector::push_back(chat, new_message);
   }




   public entry fun update_account(
       player: &signer,
       new_name: String,
       new_username: String
   ) acquires PlayerAccounts, PlayerAccount {
       let player_address = signer::address_of(player);

       if (!exists<PlayerAccount>(player_address)) {
           create_account(player, string::utf8(DEFAULT_NAME));
       };

       let player_account = borrow_global_mut<PlayerAccount>(player_address);
      
       // update name
       if (string::length(&new_name) > 0) {
           player_account.name = new_name;
       };

       // update username if it hasn't been updated before
       if (string::length(&new_username) > 0 && !player_account.has_updated_username) {
           // Check if the new username is unique
           let player_accounts = borrow_global<PlayerAccounts>(@admin);
           let accounts = &player_accounts.accounts;
           let len = vector::length(accounts);
           let i = 0;
          
           while (i < len) {
               let account = vector::borrow(accounts, i);
               assert!(account.username != new_username, E_USERNAME_ALREADY_EXISTS);
               i = i + 1;
           };

           player_account.username = new_username;
           player_account.has_updated_username = true;
       } else if (string::length(&new_username) > 0 && player_account.has_updated_username) {
           // if trying to update username again, throw an error
           abort E_USERNAME_ALREADY_UPDATED;
       };


       // update the global list
       let player_accounts = borrow_global_mut<PlayerAccounts>(@admin);
       let accounts = &mut player_accounts.accounts;
       let len = vector::length(accounts);
       let i = 0;


       while (i < len) {
           let account = vector::borrow_mut(accounts, i);
           if (account.address_id == player_address) {
               *account = *player_account;
               break;
           };
           i = i + 1;
       };
   }


   // fun init_room_chat(room_id: u64) {
   //     move_to(@admin, RoomChat {
   //         room_id,
   //         messages: vector::empty<ChatMessage>(),
   //     });
   // }


   public entry fun send_message_room_id(
       sender: &signer,
       room_id: u64,
       message: String
   ) acquires RoomState, RoomChat {
       let sender_address = signer::address_of(sender);
      
       assert!(is_player_in_room(sender_address, room_id), E_NOT_AUTHORIZED);


       assert!(exists<RoomChat>(@admin), E_ROOM_NOT_FOUND);
       let chat = borrow_global_mut<RoomChat>(@admin);
       assert!(chat.room_id == room_id, E_ROOM_NOT_FOUND);


       let new_message = ChatMessage {
           sender: sender_address,
           message,
           timestamp: timestamp::now_seconds(),
       };
       vector::push_back(&mut chat.messages, new_message);
   }



   public entry fun join_room_by_room_id(
       player2: &signer,
       room_id: u64
   ) acquires RoomState, PlayerAccounts, PlayerAccount { 
       let player2_address = signer::address_of(player2);


       // check if player2 is already in an active room
       assert!(!is_player_in_active_room(player2_address), E_PLAYER_ALREADY_IN_ACTIVE_ROOM);


       let state = borrow_global_mut<RoomState>(@admin);
      
       let room_index = 0;
       let room_found = false;


       if (!exists<PlayerAccount>(player2_address)) {
           create_account(player2, string::utf8(DEFAULT_NAME));
       };


       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id && !room.is_player2_joined && !room.is_room_close) {
               // check if the player trying to join is not the creator
               assert!(room.creator != player2_address, E_NOT_AUTHORIZED);
          
               // check if the joining player is the invited friend
               if (option::is_some(&room.invited_friend_username)) {
                   let invited_username = option::borrow(&room.invited_friend_username);
                   let player2_username = get_player_username(player2_address);
                   assert!(*invited_username == player2_username, E_NOT_AUTHORIZED);
               };


               // found the room, join it
               room.is_player2_joined = true;
               room.player2 = option::some(player2_address);


               // withdraw bet amount from player2
               let bet_coin = coin::withdraw<AptosCoin>(player2, room.bet_amount);


               // add bet amount to the pool
               let pool_index = 0;
               while (pool_index < vector::length(&state.pools)) {
                   let pool = vector::borrow_mut(&mut state.pools, pool_index);
                   if (pool.room_id == room_id) {
                       pool.total_amount = pool.total_amount + room.bet_amount;
                       break;
                   };
                   pool_index = pool_index + 1;
               };


               // deposit bet amount to admin account (representing the pool)
               coin::deposit(@admin, bet_coin);


               room_found = true;
               break;
           };
           room_index = room_index + 1;
       };
       assert!(room_found, E_ROOM_NOT_FOUND);
   }


   fun is_username_exists(username: String): bool acquires PlayerAccounts {
       let player_accounts = borrow_global<PlayerAccounts>(@admin);
       let accounts = &player_accounts.accounts;
       let len = vector::length(accounts);
       let i = 0;
      
       while (i < len) {
           let account = vector::borrow(accounts, i);
           if (account.username == username) {
               return true
           };
           i = i + 1;
       };
       false
   }

   public entry fun create_room_mate(
       creator: &signer,
       room_name: String,
       bet_amount: u64,
       friend_username: String
   ) acquires RoomState, PlayerAccounts {
       let creator_address = signer::address_of(creator);
      
       // check if the creator is already in an active room
       assert!(!is_player_in_active_room(creator_address), E_PLAYER_ALREADY_IN_ACTIVE_ROOM);

       // check if the friend exists
       assert!(is_username_exists(friend_username), E_PLAYER_ACCOUNT_NOT_EXIST);

       let current_time = timestamp::now_seconds();
       let bet_coin = coin::withdraw<AptosCoin>(creator, bet_amount);

       if (!exists<PlayerAccount>(creator_address)) {
           create_account(creator, string::utf8(DEFAULT_NAME));
       };

       let room = Room {
           creator: creator_address,
           room_id: current_time,
           room_name,
           create_time: current_time,
           bet_amount,
           is_creator_joined: true,
           creator_ready: true,
           is_player2_joined: false,
           player2: option::none<address>(),
           is_player2_ready: false,
           is_room_close: false,
           winner: option::none<address>(),
           invited_friend_username: option::some(friend_username),
       };

       let state = borrow_global_mut<RoomState>(@admin);
       vector::push_back(&mut state.rooms, room);

       // create pool for the room
       let pool = Pool {
           room_id: current_time,
           total_amount: bet_amount,
       };
       vector::push_back(&mut state.pools, pool);

       let event = RoomCreatedEvent {
           creator: creator_address,
           room_id: current_time,
           room_name,
           bet_amount,
       };
       emit_event(&mut state.room_created_events, event);

       // deposit bet amount to admin account (representing the pool)
       coin::deposit(@admin, bet_coin);
   }


   public entry fun add_friend(
   player: &signer,
   friend_username: String
) acquires PlayerAccounts, FriendList {
   let player_address = signer::address_of(player);
  
   // ensure the friend exists
   assert!(is_username_exists(friend_username), E_PLAYER_ACCOUNT_NOT_EXIST);
  
   // get the friend's address
   let friend_address = get_address_by_username(friend_username);
  
   // ensure player is not adding themselves
   assert!(player_address != friend_address, E_CANNOT_ADD_SELF);
  
   // initialize FriendList if it doesn't exist
   if (!exists<FriendList>(player_address)) {
       move_to(player, FriendList { friends: vector::empty() });
   };
  
   let friend_list = borrow_global_mut<FriendList>(player_address);
  
   // check if friend is already in the list
   assert!(!vector::contains(&friend_list.friends, &friend_address), E_ALREADY_FRIENDS);
  
   // add friend to the list
   vector::push_back(&mut friend_list.friends, friend_address);
}


// helper function to get address by username
fun get_address_by_username(username: String): address acquires PlayerAccounts {
   let player_accounts = borrow_global<PlayerAccounts>(@admin);
   let accounts = &player_accounts.accounts;
   let len = vector::length(accounts);
   let i = 0;
  
   while (i < len) {
       let account = vector::borrow(accounts, i);
       if (account.username == username) {
           return account.address_id
       };
       i = i + 1;
   };
  
   abort E_PLAYER_ACCOUNT_NOT_EXIST
}



  //ready room
   public entry fun ready_by_room_id(
       player: &signer,
       room_id: u64
   ) acquires RoomState {
       let player_address = signer::address_of(player);
       let state = borrow_global_mut<RoomState>(@admin);
      
       let room_index = 0;
       let room_found = false;
      
       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id) {
               if (room.creator == player_address) {
                   // player is the creator
                   room.creator_ready = !room.creator_ready;  // toggle the ready status
                   room_found = true;
               } else if (option::contains(&room.player2, &player_address)) {
                   // player is player2
                   room.is_player2_ready = !room.is_player2_ready;  // toggle the ready status (i think i am gonna remove this shit...)
                   room_found = true;
               } else {
                   // player is neither creator nor player2
                   assert!(false, E_ROOM_NOT_FOUND);
               };
              
               break;
           };
           room_index = room_index + 1;
       };
      
       assert!(room_found, E_ROOM_NOT_FOUND);
   }




   public entry fun give_like_account(
       liker: &signer,
       liked_address: address
   ) acquires PlayerAccount {
       let liker_address = signer::address_of(liker);
       assert!(liker_address != liked_address, E_CANNOT_LIKE_SELF);
       assert!(exists<PlayerAccount>(liked_address), E_PLAYER_ACCOUNT_NOT_EXIST);


       let liker_account = borrow_global_mut<PlayerAccount>(liker_address);
       assert!(!vector::contains(&liker_account.liked_players, &liked_address), E_ALREADY_LIKED);


       // Remove dislike if it exists
       let (had_dislike, dislike_index) = vector::index_of(&liker_account.disliked_players, &liked_address);
       if (had_dislike) {
           vector::remove(&mut liker_account.disliked_players, dislike_index);
       };


       // add like
       vector::push_back(&mut liker_account.liked_players, liked_address);


       // update the liked account
       let liked_account = borrow_global_mut<PlayerAccount>(liked_address);
       liked_account.likes_received = liked_account.likes_received + 1;
       if (had_dislike) {
           liked_account.dislikes_received = liked_account.dislikes_received - 1;
       };
   }




   public entry fun give_dislike_account(
       disliker: &signer,
       disliked_address: address
   ) acquires PlayerAccount {
       let disliker_address = signer::address_of(disliker);
       assert!(disliker_address != disliked_address, E_CANNOT_DISLIKE_SELF);
       assert!(exists<PlayerAccount>(disliked_address), E_PLAYER_ACCOUNT_NOT_EXIST);


       let disliker_account = borrow_global_mut<PlayerAccount>(disliker_address);
       assert!(!vector::contains(&disliker_account.disliked_players, &disliked_address), E_ALREADY_DISLIKED);


       // remove like if it exists
       let (had_like, like_index) = vector::index_of(&disliker_account.liked_players, &disliked_address);
       if (had_like) {
           vector::remove(&mut disliker_account.liked_players, like_index);
       };


       // add dislike
       vector::push_back(&mut disliker_account.disliked_players, disliked_address);


       // update the disliked account
       let disliked_account = borrow_global_mut<PlayerAccount>(disliked_address);
       disliked_account.dislikes_received = disliked_account.dislikes_received + 1;
       if (had_like) {
           disliked_account.likes_received = disliked_account.likes_received - 1;
       };
   }


  // admin role: pick winner in the room
   public entry fun pick_winner_and_transfer_bet(
       admin: &signer,
       room_id: u64,
       winner_address: address
   ) acquires RoomState, PlayerAccount {
       // ensure only the admin can call this function
       assert!(signer::address_of(admin) == @admin, E_NOT_AUTHORIZED);


       let state = borrow_global_mut<RoomState>(@admin);
      
       let room_index = 0;
       let room_found = false;
       let bet_amount = 0;
      
       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id && !room.is_room_close) {
               // found the room
               room_found = true;
               bet_amount = room.bet_amount;
              
               // check if both players have joined and are ready
               assert!(room.is_player2_joined, E_PLAYER_ACCOUNTS_NOT_EXIST);
               assert!(room.creator_ready && room.is_player2_ready, E_PLAYER_ALREADY_READY);
              
               // check if the winner is valid
               assert!(room.creator == winner_address || option::contains(&room.player2, &winner_address), E_INVALID_WINNER);
              
               // determine the loser
               let loser_address: address;
               if (room.creator == winner_address) {
                   assert!(option::is_some(&room.player2), E_PLAYER_ACCOUNT_NOT_FOUND);
                   loser_address = *option::borrow(&room.player2);
               } else {
                   loser_address = room.creator;
               };
              
               // set the winner and close the room
               room.winner = option::some(winner_address);
               room.is_room_close = true;


               // update points for winner and loser
               update_player_points(winner_address, true);
               update_player_points(loser_address, false);


               break;
           };
           room_index = room_index + 1;
       };
      
       assert!(room_found, E_ROOM_NOT_FOUND);

       // find and update the pool
       let pool_index = 0;
       let pool_found = false;
      
       while (pool_index < vector::length(&state.pools)) {
           let pool = vector::borrow_mut(&mut state.pools, pool_index);
           if (pool.room_id == room_id) {
               pool_found = true;
              
               // transfer the total amount to the winner
               let winner_amount = coin::withdraw<AptosCoin>(admin, pool.total_amount);
               coin::deposit(winner_address, winner_amount);
              
               // reset the pool amount
               pool.total_amount = 0;
              
               break;
           };
           pool_index = pool_index + 1;
       };
       assert!(pool_found, E_ROOM_NOT_FOUND);
   }

    //leave room (make sure player2_is_ready = false)
    public entry fun leave_room_by_room_id(
       player: &signer,
       room_id: u64
   ) acquires RoomState {
       let player_address = signer::address_of(player);
       let state = borrow_global_mut<RoomState>(@admin);
       let room_index = 0;
       let room_found = false;
       let pool_index = 0;
       let pool_found = false;

       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id) {
               assert!(!room.is_room_close, E_NOT_AUTHORIZED); // can't leave a closed room
              
               // Find the corresponding pool
               while (pool_index < vector::length(&state.pools)) {
                   let pool = vector::borrow_mut(&mut state.pools, pool_index);
                   if (pool.room_id == room_id) {
                       pool_found = true;
                       break;
                   };
                   pool_index = pool_index + 1;
               };
               assert!(pool_found, E_ROOM_NOT_FOUND);
              
               let pool = vector::borrow_mut(&mut state.pools, pool_index);
              
               if (room.creator == player_address) {
                   // Creator is leaving
                   if (room.is_player2_joined) {
                       // if player2 has joined, just mark creator as not ready
                       room.creator_ready = false;
                   } else {
                       // if player2 hasn't joined, close the room
                       room.is_room_close = true;
                   };
                  
                   // refund creator's bet from the pool
                   let refund_amount = if (pool.total_amount >= room.bet_amount) { room.bet_amount } else { pool.total_amount };
                   if (refund_amount > 0) {
                       coin::transfer<AptosCoin>(&account::create_signer_with_capability(&state.admin_cap), player_address, refund_amount);
                       pool.total_amount = pool.total_amount - refund_amount;
                   };
               } else if (option::contains(&room.player2, &player_address)) {
                   // player2 is leaving
                   room.is_player2_joined = false;
                   room.is_player2_ready = false;
                   room.player2 = option::none();
                  
                   // Refund player2's bet from the pool
                   let refund_amount = if (pool.total_amount >= room.bet_amount) { room.bet_amount } else { pool.total_amount };
                   if (refund_amount > 0) {
                       coin::transfer<AptosCoin>(&account::create_signer_with_capability(&state.admin_cap), player_address, refund_amount);
                       pool.total_amount = pool.total_amount - refund_amount;
                   };
               } else {
                   // player is neither creator nor player2
                   assert!(false, E_NOT_AUTHORIZED);
               };
               room_found = true;
               break;
           };
           room_index = room_index + 1;
       };
       assert!(room_found, E_ROOM_NOT_FOUND);
   }

  //parse u64 to string
   fun u64_to_string(value: u64): String {
       if (value == 0) {
           return string::utf8(b"0")
       };
       let buffer = vector::empty<u8>();
       while (value != 0) {
           let digit = ((value % 10) as u8) + 48;
           vector::push_back(&mut buffer, digit);
           value = value / 10;
       };
       vector::reverse(&mut buffer);
       string::utf8(buffer)
   }

  //update point
   public fun update_player_points(player_address: address, is_winner: bool) acquires PlayerAccount {
       if (exists<PlayerAccount>(player_address)) {
           let player_account = borrow_global_mut<PlayerAccount>(player_address);
           if (is_winner) {
               player_account.points = player_account.points + 10;
           } else {
               if (player_account.points >= 10) {
                   player_account.points = player_account.points - 10;
               } else {
                   player_account.points = 0;
               }
           };
           player_account.games_played = player_account.games_played + 1;  // increment games_played
       }
   }



  //init_game func
   public entry fun init_contract(admin: &signer) {
       let admin_address = signer::address_of(admin);
       assert!(admin_address == @admin, E_NOT_AUTHORIZED);
       let event_handle = account::new_event_handle<RoomCreatedEvent>(admin);
      
       let (admin_signer, admin_cap) = account::create_resource_account(admin, b"ADMIN_RESOURCE_ACCOUNT");
      
       let state = RoomState {
           rooms: vector::empty<Room>(),
           room_created_events: event_handle,
           pools: vector::empty<Pool>(),
           admin_cap,
           chats: simple_map::create<u64, vector<ChatMessage>>(), // init chats
           global_chat: vector::empty<GlobalChatMessage>(),
       };


       move_to(admin, state);


       // init PlayerAccounts
       let player_accounts = PlayerAccounts {
           accounts: vector::empty<PlayerAccount>(),
       };
       move_to(admin, player_accounts);
   }


    // === Public-Helper-View Functions ===


   //views func
   #[view]
   public fun get_all_rooms(): vector<Room> acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       state.rooms
   }


   #[view]
   public fun get_player_info(player_address: address): (String, String, u64, u64, u64, u64, u64, u64) acquires PlayerAccount {
       assert!(exists<PlayerAccount>(player_address), E_PLAYER_ACCOUNT_NOT_EXIST);
      
       let account = borrow_global<PlayerAccount>(player_address);
      
       (
           account.username,
           account.name,
           account.points,
           account.games_played,
           account.winning_games,
           0, // placeholder for pool
           account.likes_received,
           account.dislikes_received
       )
   }


   #[view]
   public fun room_detail_by_room_id(room_id: u64): Room acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       let len = vector::length(&state.rooms);
       let i = 0;
      
       while (i < len) {
           let room = vector::borrow(&state.rooms, i);
           if (room.room_id == room_id) {
               return *room
           };
           i = i + 1;
       };
      
       abort E_ROOM_NOT_FOUND
   }


   #[view]
   public fun get_room_now(player_address: address): Option<Room> acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       let len = vector::length(&state.rooms);
       let i = len;


       while (i > 0) {
           i = i - 1;
           let room = vector::borrow(&state.rooms, i);
           if (!room.is_room_close &&
               (room.creator == player_address ||
               (option::is_some(&room.player2) && option::borrow(&room.player2) == &player_address))) {
               return option::some(*room)
           };
       };


       option::none()
   }

  //get username of player (address)
   #[view]
   public fun get_player_username(player_address: address): String acquires PlayerAccount {
       assert!(exists<PlayerAccount>(player_address), E_PLAYER_ACCOUNT_NOT_EXIST);
      
       let account = borrow_global<PlayerAccount>(player_address);
      
       account.username
   }

  //super search: room, username, room id, creator,...
  #[view]
    public fun search_rooms(search_term: String): SimpleMap<u64, SearchResult> acquires RoomState, PlayerAccount {
        let state = borrow_global<RoomState>(@admin);
        let result = simple_map::create<u64, SearchResult>();
        let i = 0;
        let len = vector::length(&state.rooms);
        
        while (i < len) {
            let room = vector::borrow(&state.rooms, i);
            let creator_username = get_player_username(room.creator);
            
            if (case_insensitive_contains(&room.room_name, &search_term) ||
                case_insensitive_contains(&creator_username, &search_term) ||
                (option::is_some(&room.player2) &&
                case_insensitive_contains(&get_player_username(*option::borrow(&room.player2)), &search_term))) {
                
                let search_result = SearchResult {
                    room_id: room.room_id,
                    room_name: room.room_name,
                    creator_username,
                    player2_username: if (option::is_some(&room.player2)) {
                        option::some(get_player_username(*option::borrow(&room.player2)))
                    } else {
                        option::none()
                    },
                    bet_amount: room.bet_amount,
                    is_room_close: room.is_room_close,
                };
                simple_map::add(&mut result, room.room_id, search_result);
            };
            
            i = i + 1;
        };
        result
    }

    // custom case-insensitive string contains function
    fun case_insensitive_contains(haystack: &String, needle: &String): bool {
        let haystack_bytes = string::bytes(haystack);
        let needle_bytes = string::bytes(needle);
        let haystack_length = vector::length(haystack_bytes);
        let needle_length = vector::length(needle_bytes);
        
        if (needle_length > haystack_length) {
            return false
        };

        let i = 0;
        while (i <= haystack_length - needle_length) {
            let slice = vector::slice(haystack_bytes, i, i + needle_length);
            if (case_insensitive_equal(&slice, needle_bytes)) {
                return true
            };
            i = i + 1;
        };
        false
    }

    // custom case-insensitive equality check for byte vector references
    fun case_insensitive_equal(a: &vector<u8>, b: &vector<u8>): bool {
        let len_a = vector::length(a);
        let len_b = vector::length(b);
        
        if (len_a != len_b) {
            return false
        };
        
        let i = 0;
        while (i < len_a) {
            let char_a = to_lowercase_char(*vector::borrow(a, i));
            let char_b = to_lowercase_char(*vector::borrow(b, i));
            if (char_a != char_b) {
                return false
            };
            i = i + 1;
        };
        true
    }

    // convert a single character to lowercase
    fun to_lowercase_char(c: u8): u8 {
        if (c >= 65 && c <= 90) { // ASCII values for 'A' to 'Z'
            c + 32
        } else {
            c
        }
    }



    // // helper function to check if a string contains another string
    // fun string_contains(haystack: &String, needle: &String): bool {
    //     let haystack_length = string::length(haystack);
    //     let needle_length = string::length(needle);
        
    //     if (needle_length > haystack_length) {
    //         return false
    //     };

    //     let i = 0;
    //     while (i <= haystack_length - needle_length) {
    //         if (string::sub_string(haystack, i, i + needle_length) == *needle) {
    //             return true
    //         };
    //         i = i + 1;
    //     };
    //     false
    // }


   #[view]
   public fun get_top_100_players(): vector<PlayerData> acquires PlayerAccounts {
       let player_accounts = borrow_global<PlayerAccounts>(@admin);
       let accounts = &player_accounts.accounts;
       let len = vector::length(accounts);
      
       // create a vector to store player data
       let player_data = vector::empty<PlayerData>();
      
       // populate player_data
       let i = 0;
       while (i < len) {
           let account = vector::borrow(accounts, i);
           vector::push_back(&mut player_data, PlayerData {
               address: account.address_id,
               points: account.points,
               games_played: account.games_played,
               winning_games: account.winning_games,
           });
           i = i + 1;
       };
      
       // sort player_data by points in descending order
       sort_players_by_points(&mut player_data);
      
       // take top 100 or less if there are fewer players
       let top_100 = vector::empty<PlayerData>();
       let j = 0;
       while (j < 100 && j < vector::length(&player_data)) {
           vector::push_back(&mut top_100, *vector::borrow(&player_data, j));
           j = j + 1;
       };
      
       top_100
   }


   // helper function to sort players by points in descending order
   fun sort_players_by_points(players: &mut vector<PlayerData>) {
       let len = vector::length(players);
       let i = 0;
       while (i < len) {
           let j = i + 1;
           while (j < len) {
               let player_i = vector::borrow(players, i);
               let player_j = vector::borrow(players, j);
               if (player_j.points > player_i.points) {
                   vector::swap(players, i, j);
               };
               j = j + 1;
           };
           i = i + 1;
       };
   }

  //get chat in room id
   #[view]
   public fun get_chat_messages(room_id: u64): vector<ChatMessage> acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       assert!(simple_map::contains_key(&state.chats, &room_id), E_ROOM_NOT_FOUND);
       *simple_map::borrow(&state.chats, &room_id)
   }

  //get global chat
   #[view]
   public fun get_global_chat_messages(): vector<GlobalChatMessage> acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       state.global_chat
   }

  // get friend list by address
   #[view]
   public fun get_friend_list(player_address: address): vector<address> acquires FriendList {
       assert!(exists<FriendList>(player_address), E_FRIEND_LIST_NOT_INITIALIZED);
      
       let friend_list = borrow_global<FriendList>(player_address);
       friend_list.friends
   }
}
