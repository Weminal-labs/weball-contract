module admin::gamev2 {
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::event::{EventHandle, emit_event};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use std::option::{Option, Self};
    // Errors
    const E_ROOM_NOT_FOUND: u64 = 1003;


    // Constants for default values
    const DEFAULT_NAME: vector<u8> = b"No name";
    const DEFAULT_IMAGE_LINK: vector<u8> = b"Image address not found";
    const DEFAULT_HASH: vector<u8> = b"not found";

    // Struct
    struct Room has key, store, copy {
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
    }

    // Event 
    struct RoomCreatedEvent has store, drop {
        creator: address,
        room_id: u64,
        room_name: String,
        bet_amount: u64,
    }

    // State management for rooms
    struct RoomState has key {
        rooms: vector<Room>,
        room_created_events: EventHandle<RoomCreatedEvent>,
    }

    // Struct to define Player Account
    struct PlayerAccount has store, drop {
        name: String,
        address_id: address,
        image_link: String,
        hash: String,
        points: u64,
    }

    // Resource to hold PlayerAccounts
    struct PlayerAccounts has key {
        accounts: vector<PlayerAccount>,
    }

    // Create a player account
    public entry fun create_account(
        signer: &signer,
        name: Option<vector<u8>>,
        image_link: Option<vector<u8>>,
        hash: Option<vector<u8>>,
    ) acquires PlayerAccounts {
        let account_address = signer::address_of(signer);

        // Determine the values to use (defaults or provided)
        let player_name_bytes = if (option::is_some(&name)) {
            *option::borrow(&name)
        } else {
            DEFAULT_NAME
        };

        let player_image_link_bytes = if (option::is_some(&image_link)) {
            *option::borrow(&image_link)
        } else {
            DEFAULT_IMAGE_LINK
        };

        let player_hash_bytes = if (option::is_some(&hash)) {
            *option::borrow(&hash)
        } else {
            DEFAULT_HASH
        };

        // Convert bytes to strings
        let player_name = string::utf8(player_name_bytes);
        let player_image_link = string::utf8(player_image_link_bytes);
        let player_hash = string::utf8(player_hash_bytes);

        // Create the player account
        let player_account = PlayerAccount {
            name: player_name,
            address_id: account_address,
            image_link: player_image_link,
            hash: player_hash,
            points: 0, // Default starting points
        };

        // Check if PlayerAccounts resource exists
        if (!exists<PlayerAccounts>(account_address)) {
            let accounts = PlayerAccounts {
                accounts: vector::empty<PlayerAccount>(),
            };
            move_to(signer, accounts);
        };

        // Add player account to the accounts vector
        let accounts = borrow_global_mut<PlayerAccounts>(account_address);
        vector::push_back(&mut accounts.accounts, player_account);
    }

    // Create a new room with provided parameters
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
        };

        let state = borrow_global_mut<RoomState>(@admin);
        vector::push_back(&mut state.rooms, room);
        let event = RoomCreatedEvent {
            creator: creator_address,
            room_id: current_time,
            room_name,
            bet_amount,
        };
        emit_event(&mut state.room_created_events, event);
        coin::deposit<AptosCoin>(creator_address, bet_coin);
    }
    // Init contract
    public entry fun init_contract(admin: &signer) {
        let event_handle = account::new_event_handle<RoomCreatedEvent>(admin);
        let state = RoomState {
            rooms: vector::empty<Room>(),
            room_created_events: event_handle,
        };
        move_to(admin, state);
    }

    #[view]
    public fun get_all_rooms(): vector<Room> acquires RoomState {
        let state = borrow_global<RoomState>(@admin);
        state.rooms
    }
}
