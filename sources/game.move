module admin::gamev3 {
  use std::signer;
  use std::string::{Self, String};
  use std::vector;
  use aptos_framework::coin;
  use aptos_framework::aptos_coin::{AptosCoin};
  use aptos_framework::event::{EventHandle, emit_event};
  use aptos_framework::timestamp;
  use aptos_framework::account;
  use std::option::{Option, Self};


  //errors handling
  const E_ROOM_NOT_FOUND: u64 = 1003;
  const E_PLAYER_ALREADY_READY: u64 = 1004;
  const E_PLAYER_ACCOUNTS_NOT_EXIST: u64 = 1005;
  const E_PLAYER_ACCOUNT_NOT_FOUND: u64 = 1006;
  const E_NOT_AUTHORIZED: u64 = 1007;
  const E_PLAYER_ACCOUNT_NOT_EXIST: u64 = 1008;
  const E_INVALID_WINNER: u64 = 1009;
  const E_REFUND_POOL_NOT_EXIST: u64 = 1010;




  // constants for default values
  const DEFAULT_NAME: vector<u8> = b"No name";
  const DEFAULT_IMAGE_LINK: vector<u8> = b"Image address not found";
  const DEFAULT_HASH: vector<u8> = b"not found";
  const SEED: vector<u8> = b"REFUND_POOL_RESOURCE_ACCOUNT";
 
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
   }


  // struct to define player account
   struct PlayerAccount has key, store {
       name: String,
       address_id: address,
       image_link: String,
       hash: String,
       points: u64,
       games_played: u64,
       winning_games: u64,
   }






  // resource to hold playeraccounts
  struct PlayerAccounts has key {
       accounts: vector<PlayerAccount>,
   }




  struct Pool has key, store {
       room_id: u64,
       total_amount: u64,
   }


   struct RefundPool has key, store {
       amount: u64,
   }


   struct RefundResourceAccount has key {
       signer_cap: account::SignerCapability,
   }


   struct PlayerScore has copy, drop, store {
       address: address,
       score: u64,
   }






  // function to create a player account
   public entry fun create_account(
       signer: &signer,
       name: String,
       image_link: String,
       hash: String,
   ) acquires PlayerAccounts {
       let account_address = signer::address_of(signer);


       let player_name = if (string::length(&name) > 0) {
       name
   } else {
       string::utf8(DEFAULT_NAME)
   };


       let player_image_link = if (string::length(&image_link) > 0) {
       image_link
   } else {
       string::utf8(DEFAULT_IMAGE_LINK)
   };


       let player_hash = if (string::length(&hash) > 0) {
       hash
   } else {
       string::utf8(DEFAULT_HASH)
   };


       let player_account = PlayerAccount { name: player_name,
           address_id: account_address,
           image_link: player_image_link,
           hash: player_hash,
           points: 0,
           games_played: 0,
           winning_games: 0,
   };
       let player_accounts = borrow_global_mut<PlayerAccounts>(@admin); vector::push_back(&mut player_accounts.accounts, player_account);


   }


   // function to create a new room with provided parameters
   public entry fun create_room(
       creator: &signer,
       room_name: String,
       bet_amount: u64
   ) acquires RoomState {
       let creator_address = signer::address_of(creator);
       let current_time = timestamp::now_seconds();
       let bet_coin = coin::withdraw<AptosCoin>(creator, bet_amount);


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




   public entry fun join_room_by_room_id(
       player2: &signer,
       room_id: u64
   ) acquires RoomState {
       let player2_address = signer::address_of(player2);
       let state = borrow_global_mut<RoomState>(@admin);
      
       let room_index = 0;
       let room_found = false;




       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id && !room.is_player2_joined && !room.is_room_close) {
               // Check if the player trying to join is not the creator
               assert!(room.creator != player2_address, E_NOT_AUTHORIZED);
          
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
                   room.creator_ready = !room.creator_ready;  // Toggle the ready status
                   room_found = true;
               } else if (option::contains(&room.player2, &player_address)) {
                   // player is player2
                   room.is_player2_ready = !room.is_player2_ready;  // Toggle the ready status
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






   public entry fun leave_room_by_room_id(
       player: &signer,
       room_id: u64
   ) acquires RoomState, RefundResourceAccount, RefundPool {
       let player_address = signer::address_of(player);
       let state = borrow_global_mut<RoomState>(@admin);
       let room_index = 0;
       let room_found = false;
       while (room_index < vector::length(&state.rooms)) {
           let room = vector::borrow_mut(&mut state.rooms, room_index);
           if (room.room_id == room_id) {
               if (room.creator == player_address) {
                   // scenario 1: creator is leaving
                   assert!(!room.is_player2_joined, E_NOT_AUTHORIZED); // Can't leave if player2 has joined
                   room.is_room_close = true;
                   // create or update refund pool for creator
                   create_or_update_refund_pool(player, room.bet_amount);
                   // Immediately claim the refund
                   claim_refund(player);
               } else if (option::contains(&room.player2, &player_address)) {
                   // scenario 2: player2 is leaving
                   assert!(!room.is_player2_ready, E_NOT_AUTHORIZED); // Can't leave if ready
                   room.is_player2_joined = false;
                   room.player2 = option::none();
                   // create or update refund pool for player2
                   create_or_update_refund_pool(player, room.bet_amount);
                   // Immediately claim the refund
                   claim_refund(player);
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






   // helper function to create or update a RefundPool
   public entry fun create_or_update_refund_pool(player: &signer, amount: u64)
       acquires RefundResourceAccount, RefundPool
   {
       let player_address = signer::address_of(player);
      
       // Get the resource account's signer capability
       let refund_resource_account = borrow_global<RefundResourceAccount>(@admin);
       let resource_signer = account::create_signer_with_capability(&refund_resource_account.signer_cap);
       let resource_account_address = signer::address_of(&resource_signer);




       if (!exists<RefundPool>(player_address)) {
           move_to(player, RefundPool { amount });
       } else {
           let refund_pool = borrow_global_mut<RefundPool>(player_address);
           refund_pool.amount = refund_pool.amount + amount;
       };




       // Transfer the funds to the resource account
       coin::transfer<AptosCoin>(player, resource_account_address, amount);
   }










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




   // function for players to claim their refunds
   public entry fun claim_refund(player: &signer) acquires RefundPool, RefundResourceAccount {
       let player_address = signer::address_of(player);
       assert!(exists<RefundPool>(player_address), E_REFUND_POOL_NOT_EXIST);




       let RefundPool { amount } = move_from<RefundPool>(player_address);
      
       let refund_resource_account = borrow_global<RefundResourceAccount>(@admin);
       let resource_signer = account::create_signer_with_capability(&refund_resource_account.signer_cap);




       // Transfer the refund from the resource account to the player
       coin::transfer<AptosCoin>(&resource_signer, player_address, amount);
   }










   public entry fun init_contract(admin: &signer) {
       let admin_address = signer::address_of(admin);
       assert!(admin_address == @admin, E_NOT_AUTHORIZED);




       let event_handle = account::new_event_handle<RoomCreatedEvent>(admin);
       let (resource_signer, signer_cap) = account::create_resource_account(admin, SEED);
      
       let state = RoomState {
           rooms: vector::empty<Room>(),
           room_created_events: event_handle,
           pools: vector::empty<Pool>(),
       };
       move_to(admin, state);




       // initialize PlayerAccounts
       let player_accounts = PlayerAccounts {
           accounts: vector::empty<PlayerAccount>(),
       };
       move_to(admin, player_accounts);




       // store the RefundResourceAccount
       move_to(admin, RefundResourceAccount { signer_cap });
   }






   //views func
  #[view]
  public fun get_all_rooms(): vector<Room> acquires RoomState {
      let state = borrow_global<RoomState>(@admin);
      state.rooms
  }


 #[view]
   public fun get_player_info(player_address: address): (String, String, String, u64) acquires PlayerAccount {
       assert!(exists<PlayerAccount>(player_address), E_PLAYER_ACCOUNT_NOT_EXIST);
      
       let account = borrow_global<PlayerAccount>(player_address);
      
       (account.name, account.image_link, account.hash, account.points)
   }


   #[view]
   public fun room_detail_by_room_id(room_id: u64): (address, u64, String, u64, u64, bool, bool, bool, Option<address>, bool, bool, Option<address>) acquires RoomState {
       let state = borrow_global<RoomState>(@admin);
       let len = vector::length(&state.rooms);
       let i = 0;
       let found = false;




       let creator = @0x0;
       let room_name = string::utf8(b"");
       let create_time = 0u64;
       let bet_amount = 0u64;
       let is_creator_joined = false;      
       let creator_ready = false;
       let is_player2_joined = false;
       let player2 = option::none<address>();
       let is_player2_ready = false;
       let is_room_close = false;
       let winner = option::none<address>();




       while (i < len) {
           let room = vector::borrow(&state.rooms, i);
           if (room.room_id == room_id) {
               creator = room.creator;
               room_name = room.room_name;
               create_time = room.create_time;
               bet_amount = room.bet_amount;
               is_creator_joined = room.is_creator_joined;              
               creator_ready = room.creator_ready;
               is_player2_joined = room.is_player2_joined;
               player2 = room.player2;
               is_player2_ready = room.is_player2_ready;
               is_room_close = room.is_room_close;
               winner = room.winner;
               found = true;
               break
           };
           i = i + 1;
       };


       assert!(found, E_ROOM_NOT_FOUND);

       (
           creator,
           room_id,
           room_name,
           create_time,
           bet_amount,
           is_creator_joined,
           creator_ready,
           is_player2_joined,
           player2,
           is_player2_ready,
           is_room_close,
           winner
       )
   }
}
