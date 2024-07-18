module game::game {

    use std::option;
    use std::vector;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event::{EventHandle, emit_event};
    use aptos_framework::signer::Signer;
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table};
    use aptos_framework::account;

    // struct 
    struct CreateRoomEvent has key, store {
        room_id: u64,
        creator: address,
        bet_amount: u64,
        create_time: u64,
    }

    struct ReadyEvent has key, store {
        room_id: u64,
        player: address,
    }

    struct Room has store {
        creator: address,
        player: option::Option<address>,
        bet_amount: u64,
        ready: bool,
    }

    struct State has key {
        rooms: Table<u64, Room>,
        next_room_id: u64,
        create_room_events: EventHandle<CreateRoomEvent>,
        ready_events: EventHandle<ReadyEvent>,
        rewards: Table<address, u64>,
    }
    
    // init func
    public fun init_room(account: &signer) {
        move_to(account, State {
            rooms: Table::new(),
            next_room_id: 0,
            create_room_events: EventHandle::new<CreateRoomEvent>(account),
            ready_events: EventHandle::new<ReadyEvent>(account),
            rewards: Table::new(),
        });
    }
    
    // create room
    public fun create_room(account: &signer, bet_amount: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room_id = state.next_room_id;
        state.next_room_id = state.next_room_id + 1;

        let room = Room {
            creator: signer::address_of(account),
            player: option::none(),
            bet_amount: bet_amount,
            ready: false,
        };

        table::add(&mut state.rooms, room_id, room);

        let create_time = timestamp::now_seconds();

        let create_room_event = CreateRoomEvent {
            room_id: room_id,
            creator: signer::address_of(account),
            bet_amount: bet_amount,
            create_time: create_time,
        };

        emit_event(&mut state.create_room_events, create_room_event);

        AptosCoin::withdraw(account, bet_amount);
    }
    
    // join room
    public fun join_room(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room = table::borrow_mut(&mut state.rooms, room_id);
        assert!(option::is_none(&room.player), 101);

        room.player = option::some(signer::address_of(account));
    }
    
    // ready 
    public fun ready(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room = table::borrow_mut(&mut state.rooms, room_id);
        let player = signer::address_of(account);

        assert!(option::is_some(&room.player), 102);
        assert!(*option::borrow(&room.player) == player || room.creator == player, 103);

        room.ready = true;

        let ready_event = ReadyEvent {
            room_id: room_id,
            player: player,
        };

        emit_event(&mut state.ready_events, ready_event);

        AptosCoin::withdraw(account, room.bet_amount);
    }

    // claim 
    // public fun claim_winnings(account: &signer, room_id: u64, winner: address) {
    //     let state = borrow_global_mut<State>(signer::address_of(account));
    //     let room = table::borrow_mut(&mut state.rooms, room_id);

    //     assert!(room.ready, 104);

    //     assert!(signer::address_of(account) == winner, 105);

    //     let total_pot = room.bet_amount * 2;

    //     if !table::contains(&state.rewards, winner) {
    //         table::add(&mut state.rewards, winner, 0);
    //     }

    //     let current_reward = *table::borrow(&state.rewards, winner);
    //     table::add(&mut state.rewards, winner, current_reward + total_pot);

    //     AptosCoin::deposit(account, total_pot);

    //     table::remove(&mut state.rooms, room_id);
    // }

    // show all available rooms
    public fun show_all_rooms(): vector<u64> {
        let state = borrow_global<State>(@0x1);
        let keys = table::keys(&state.rooms);
        let mut available_rooms = vector::empty<u64>();

        let len = vector::length(&keys);
        let mut i = 0;
        while (i < len) {
            let room_id = *vector::borrow(&keys, i);
            let room = table::borrow(&state.rooms, room_id);
            if (!room.ready) {
                vector::push_back(&mut available_rooms, room_id);
            }
            i = i + 1;
        }
        available_rooms
    }

    // show reward claimed by account id
    public fun show_rewards(account: address): u64 {
        let state = borrow_global<State>(@0x1);
        if table::contains(&state.rewards, account) {
            *table::borrow(&state.rewards, account)
        } else {
            0
        }
    }

    // testing

    #[test]
    public fun test_create_room() {
        let account = @0x1;
        let bet_amount = 100;
        create_room(&account, bet_amount);

        let state = borrow_global<State>(signer::address_of(&account));
        let room_id = 0;
        let room = table::borrow(&state.rooms, room_id);

        assert!(room.creator == signer::address_of(&account), 201);
        assert!(room.bet_amount == bet_amount, 202);
        assert!(option::is_none(&room.player), 203);
    }

    #[test]
    public fun test_join_room() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        create_room(&account1, bet_amount);
        join_room(&account2, 0);

        let state = borrow_global<State>(signer::address_of(&account1));
        let room = table::borrow(&state.rooms, 0);

        assert!(option::is_some(&room.player), 301);
        assert!(*option::borrow(&room.player) == signer::address_of(&account2), 302);
    }

    #[test]
    public fun test_ready() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        create_room(&account1, bet_amount);
        join_room(&account2, 0);
        ready(&account1, 0);
        ready(&account2, 0);

        let state = borrow_global<State>(signer::address_of(&account1));
        let room = table::borrow(&state.rooms, 0);

        assert!(room.ready, 401);
    }

    // #[test]
    // public fun test_claim_winnings() {
    //     let account1 = @0x1;
    //     let account2 = @0x2;
    //     let bet_amount = 100;
    //     create_room(&account1, bet_amount);
    //     join_room(&account2, 0);
    //     ready(&account1, 0);
    //     ready(&account2, 0);

    //     claim_winnings(&account1, 0, signer::address_of(&account1));

    //     let state = borrow_global<State>(signer::address_of(&account1));
    //     let room_exists = table::contains(&state.rooms, 0);

    //     assert!(!room_exists, 501);

    //     let rewards = show_rewards(signer::address_of(&account1));
    //     assert!(rewards == 200, 502); // Total pot is bet_amount * 2
    // }

    #[test]
    public fun test_show_all_rooms() {
        let account = @0x1;
        let bet_amount = 100;
        create_room(&account, bet_amount);

        let rooms = show_all_rooms();
        assert!(vector::contains(&rooms, 0), 601);
    }
}
