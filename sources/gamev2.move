module admin::gamev2 {
    use std::signer;
    use std::string::{String, Self};
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::event::{EventHandle, emit_event};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use std::option::{Option, Self};

    const E_ROOM_NOT_FOUND: u64 = 1003;

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

    struct RoomCreatedEvent has store, drop {
        creator: address,
        room_id: u64,
        room_name: String,
        bet_amount: u64,
    }

    struct RoomState has key {
        rooms: vector<Room>,
        room_created_events: EventHandle<RoomCreatedEvent>,
    }

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
 //init contract func
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