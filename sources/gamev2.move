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
   //Errors handling
   const E_ROOM_NOT_FOUND: u64 = 1003;
   const E_PLAYER_ALREADY_READY: u64 = 1004;
   const E_PLAYER_ACCOUNTS_NOT_EXIST: u64 = 1005;
   const E_PLAYER_ACCOUNT_NOT_FOUND: u64 = 1006;
   const E_NOT_AUTHORIZED: u64 = 1007;
   const E_PLAYER_ACCOUNT_NOT_EXIST: u64 = 1008;

   // constants for default values
   const DEFAULT_NAME: vector<u8> = b"No name";
   const DEFAULT_IMAGE_LINK: vector<u8> = b"Image address not found";
   const DEFAULT_HASH: vector<u8> = b"not found";


   // struct to define a Room
   struct Room has key, store, copy, drop {
       creator: address,
       room_id: u64,
       room_name: String,
       create_time: u64,
       bet_amount: u64,
       creator_ready: bool,
       is_player2_joined: bool,
       player2: Option<address>,
       is_player2_ready: bool,
       is_room_close: bool,
       creator_score: u8,
       player2_score: u8,
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
    }



   // resource to hold playeraccounts
   struct PlayerAccounts has key {
        accounts: vector<PlayerAccount>,
    }


   struct Pool has key, store {
        room_id: u64,
        total_amount: u64,
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
            points: 0, games_played: 0, 
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
            creator_ready: true,
            is_player2_joined: false,
            player2: option::none<address>(),
            is_player2_ready: false,
            is_room_close: false,
            creator_score: 0,
            player2_score: 0,
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
                   assert!(!room.creator_ready, E_PLAYER_ALREADY_READY);
                   room.creator_ready = true;
                   room_found = true;
               } else if (option::contains(&room.player2, &player_address)) {
                   // player is player2
                   assert!(!room.is_player2_ready, E_PLAYER_ALREADY_READY);
                   room.is_player2_ready = true;
                   room_found = true;
               } else {
                   // player is neither creator nor player2
                   assert!(false, E_ROOM_NOT_FOUND);
               };
              //example
               // check if both players are ready
               // if (room.creator_ready && room.is_player2_ready) {
               //     // both players are ready, add additional logic here to start the game
               //     // start_game(room_id);
               // };
              
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
    ) acquires RoomState {
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
            
            // set the winner and close the room
                room.winner = option::some(winner_address);
                room.is_room_close = true;
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
	public entry fun update_score(
        admin: &signer,
        room_id: u64,
        scored_by_creator: bool
    ) acquires RoomState {
        assert!(signer::address_of(admin) == @admin, E_NOT_AUTHORIZED);

        let state = borrow_global_mut<RoomState>(@admin);
    
        let room_index = 0;
        let room_found = false;
    
        while (room_index < vector::length(&state.rooms)) {
            let room = vector::borrow_mut(&mut state.rooms, room_index);
            if (room.room_id == room_id) {
                if (scored_by_creator) {
                    room.creator_score = room.creator_score + 1;
                } else {
                    room.player2_score = room.player2_score + 1;
                };
                
                room_found = true;
                break;
            };
            room_index = room_index + 1;
        };
        assert!(room_found, E_ROOM_NOT_FOUND);
    }





    fun update_player_points(player_address: address, is_winner: bool
    ) acquires PlayerAccount {
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





    public entry fun init_contract(admin: &signer) {
        let event_handle = account::new_event_handle<RoomCreatedEvent>(admin);
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
    }


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
    public fun room_detail_by_room_id(room_id: u64): (address, u64, String, u64, u64, bool, bool, Option<address>, bool, bool, u8, u8, Option<address>) acquires RoomState {
        let state = borrow_global<RoomState>(@admin);
        let len = vector::length(&state.rooms);
        let i = 0;
        let found = false;

        let creator = @0x0;
        let room_name = string::utf8(b"");
        let create_time = 0u64;
        let bet_amount = 0u64;
        let creator_ready = false;
        let is_player2_joined = false;
        let player2 = option::none<address>();
        let is_player2_ready = false;
        let is_room_close = false;
        let creator_score = 0u8;
        let player2_score = 0u8;
        let winner = option::none<address>();

        while (i < len) {
            let room = vector::borrow(&state.rooms, i);
            if (room.room_id == room_id) {
                creator = room.creator;
                room_name = room.room_name;
                create_time = room.create_time;
                bet_amount = room.bet_amount;
                creator_ready = room.creator_ready;
                is_player2_joined = room.is_player2_joined;
                player2 = room.player2;
                is_player2_ready = room.is_player2_ready;
                is_room_close = room.is_room_close;
                creator_score = room.creator_score;
                player2_score = room.player2_score;
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
            creator_ready,
            is_player2_joined,
            player2,
            is_player2_ready,
            is_room_close,
            creator_score,
            player2_score,
            winner
        )
    }
    #[view]
    public fun get_top_100_players_most_points(): vector<PlayerScore> acquires PlayerAccounts {
        let player_accounts = borrow_global<PlayerAccounts>(@admin);
        let players = vector::empty<PlayerScore>();
        let i = 0;
        while (i < vector::length(&player_accounts.accounts)) {
            let account = vector::borrow(&player_accounts.accounts, i);
            vector::push_back(&mut players, PlayerScore { address: account.address_id, score: account.points });
            i = i + 1;
        };

        // sort players by points in descending order
        sort_players_by_score(&mut players);

        // take top 100 or less if there are fewer players
        let top_100 = vector::empty<PlayerScore>();
        let j = 0;
        while (j < 100 && j < vector::length(&players)) {
            vector::push_back(&mut top_100, *vector::borrow(&players, j));
            j = j + 1;
        };

        top_100
    }


    #[view]
    public fun get_top_100_player_most_game(): vector<PlayerScore> acquires PlayerAccounts {
        let player_accounts = borrow_global<PlayerAccounts>(@admin);
        let players = vector::empty<PlayerScore>();
        let i = 0;
        while (i < vector::length(&player_accounts.accounts)) {
            let account = vector::borrow(&player_accounts.accounts, i);
            vector::push_back(&mut players, PlayerScore { address: account.address_id, score: account.games_played });
            i = i + 1;
        };

        // sort players by games played in descending order
        sort_players_by_score(&mut players);

        // take top 100 or less if there are fewer players
        let top_100 = vector::empty<PlayerScore>();
        let j = 0;
        while (j < 100 && j < vector::length(&players)) {
            vector::push_back(&mut top_100, *vector::borrow(&players, j));
            j = j + 1;
        };

        top_100
    }


    fun sort_players_by_score(players: &mut vector<PlayerScore>) {
        let len = vector::length(players);
        let i = 0;
        while (i < len) {
            let j = 0;
            while (j < len - i - 1) {
                let score1 = vector::borrow(players, j).score;
                let score2 = vector::borrow(players, j + 1).score;
                if (score1 < score2) {
                    vector::swap(players, j, j + 1);
                };
                j = j + 1;
            };
            i = i + 1;
        };
    }
}
