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
        room_name: vector<u8>,
    }

    struct ReadyEvent has key, store {
        room_id: u64,
        player: address,
    }

    struct Room has store {
        room_name: vector<u8>,
        creator: address,
        player: option::Option<address>,
        bet_amount: u64,
        creator_ready: bool,
        player_ready: bool,
    }

    struct State has key {
        rooms: Table<u64, Room>,
        next_room_id: u64,
        create_room_events: EventHandle<CreateRoomEvent>,
        ready_events: EventHandle<ReadyEvent>,
        rewards: Table<address, u64>,
        deposits: Table<u64, u64>, // holds total apt deposit in the room
        player_rooms: Table<address, u64>, // tracks which room each player is in
        points: Table<address, u64>, // tracks points for each player
    }
    
    // init contract
    public fun init_room(account: &signer) {
        move_to(account, State {
            rooms: Table::new(),
            next_room_id: 0,
            create_room_events: EventHandle::new<CreateRoomEvent>(account),
            ready_events: EventHandle::new<ReadyEvent>(account),
            rewards: Table::new(),
            deposits: Table::new(),
            player_rooms: Table::new(),
            points: Table::new(),
        });
    }
    
    // create room func
    public fun create_room(account: &signer, room_name: vector<u8>, bet_amount: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room_id = state.next_room_id;
        state.next_room_id = state.next_room_id + 1;

        let room = Room {
            room_name: room_name,
            creator: signer::address_of(account),
            player: option::none(),
            bet_amount: bet_amount,
            creator_ready: true,
            player_ready: false,
        };

        table::add(&mut state.rooms, room_id, room);
        table::add(&mut state.deposits, room_id, bet_amount); // init deposit with creator's bet amount
        table::add(&mut state.player_rooms, signer::address_of(account), room_id); // track the player's room

        let create_time = timestamp::now_seconds();

        let create_room_event = CreateRoomEvent {
            room_id: room_id,
            creator: signer::address_of(account),
            bet_amount: bet_amount,
            create_time: create_time,
            room_name: room_name,
        };

        emit_event(&mut state.create_room_events, create_room_event);

        AptosCoin::withdraw(account, bet_amount);
    }
    
    // join room func
    public fun join_room_by_room_id(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let player = signer::address_of(account);
        assert!(!table::contains(&state.player_rooms, player), 109); // makesure player is not in another room

        let room = table::borrow_mut(&mut state.rooms, room_id);
        assert!(option::is_none(&room.player), 101);

        room.player = option::some(player);
        table::add(&mut state.player_rooms, player, room_id); // track player's room
    }
    
    // ready func
    public fun ready_by_room_id(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room = table::borrow_mut(&mut state.rooms, room_id);
        let player = signer::address_of(account);

        if (room.creator == player) {
            room.creator_ready = true;
        } else if (option::is_some(&room.player) && *option::borrow(&room.player) == player) {
            room.player_ready = true;
            // withdraw bet amount from joining player2 when player2 are ready
            AptosCoin::withdraw(account, room.bet_amount);
            let current_deposit = *table::borrow(&state.deposits, room_id);
            table::add(&mut state.deposits, room_id, current_deposit + room.bet_amount); // update the deposit
        } else {
            assert!(false, 102); // invalid player
        }

        let ready_event = ReadyEvent {
            room_id: room_id,
            player: player,
        };

        emit_event(&mut state.ready_events, ready_event);
    }

    // leave room func for player 1 to leave and reclaim bet amount
    public fun leave_room_by_room_id(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room = table::borrow_mut(&mut state.rooms, room_id);

        assert!(room.creator == signer::address_of(account), 106); // make sure only creator can leave the room
        assert!(option::is_none(&room.player) || !room.player_ready, 107); // make sure no player has joined or player is not ready

        // refund bet amount to creator
        AptosCoin::deposit(account, room.bet_amount);

        // Remove the room
        table::remove(&mut state.rooms, room_id);
        table::remove(&mut state.deposits, room_id);
        table::remove(&mut state.player_rooms, signer::address_of(account)); // remove the player's room tracking
    }

    // announce winner func to be called only by owner's contract
    public fun announce_winner_by_room_id(signer: &signer, room_id: u64, winner: address) {
        assert!(signer::address_of(signer) == game::game_address(), 108); // make sure only the owner's contract can call this function

        claim_winnings(winner, room_id, winner);
    }

    // claim winnings func
    public fun claim_winnings_by_room_id(account: &signer, room_id: u64) {
        let state = borrow_global_mut<State>(signer::address_of(account));
        let room = table::borrow_mut(&mut state.rooms, room_id);
        let winner = signer::address_of(account);

        assert!(room.creator_ready && room.player_ready, 104);
        assert!(winner == room.creator || (option::is_some(&room.player) && winner == *option::borrow(&room.player)), 105);

        let total_pot = *table::borrow(&state.deposits, room_id);

        if !table::contains(&state.rewards, winner) {
            table::add(&mut state.rewards, winner, 0);
        }

        let current_reward = *table::borrow(&state.rewards, winner);
        table::add(&mut state.rewards, winner, current_reward + total_pot);

        // update the winner's points
        if !table::contains(&state.points, winner) {
            table::add(&mut state.points, winner, 0);
        }
        let current_points = *table::borrow(&state.points, winner);
        table::add(&mut state.points, winner, current_points + 1);

        AptosCoin::deposit(account, total_pot);

        table::remove(&mut state.rooms, room_id);
        table::remove(&mut state.deposits, room_id);
        table::remove(&mut state.player_rooms, room.creator);
        if option::is_some(&room.player) {
            table::remove(&mut state.player_rooms, *option::borrow(&room.player));
        }
    }

    // show all rooms
    public fun show_all_rooms(): vector<u64> {
        let state = borrow_global<State>(@0x1);
        table::keys(&state.rooms)
    }

    // show all available rooms
    public fun show_all_available_rooms(): vector<u64> {
        let state = borrow_global<State>(@0x1);
        let keys = table::keys(&state.rooms);
        let mut available_rooms = vector::empty<u64>();

        let len = vector::length(&keys);
        let mut i = 0;
        while (i < len) {
            let room_id = *vector::borrow(&keys, i);
            let room = table::borrow(&state.rooms, room_id);
            if (!room.creator_ready || !room.player_ready) {
                vector::push_back(&mut available_rooms, room_id);
            }
            i = i + 1;
        }
        available_rooms
    }

    // show reward claimed by account id
    public fun show_rewards_by_account_id(account: address): u64 {
        let state = borrow_global<State>(@0x1);
        if table::contains(&state.rewards, account) {
            *table::borrow(&state.rewards, account)
        } else {
            0
        }
    }

    // show room details including players
    public fun show_room_details_by_room_id(room_id: u64): (vector<u8>, address, option::Option<address>, u64, bool, bool) {
        let state = borrow_global<State>(@0x1);
        let room = table::borrow(&state.rooms, room_id);
        (room.room_name, room.creator, room.player, room.bet_amount, room.creator_ready, room.player_ready)
    }


    public fun show_leaderboard_by_top(top_n: u64): vector<(address, u64)> {
        let state = borrow_global<State>(@0x1);
        let keys = table::keys(&state.points);
        let mut leaderboard = vector::empty<(address, u64)>();

        let len = vector::length(&keys);
        let mut i = 0;
        while (i < len) {
            let player = *vector::borrow(&keys, i);
            let points = *table::borrow(&state.points, player);
            vector::push_back(&mut leaderboard, (player, points));
            i = i + 1;
        }

        // sort leaderboard by points in descending order
        vector::sort_by(&mut leaderboard, fun((a, b): &(address, u64), (c, d): &(address, u64)): bool {
            b > d
        });

        // return the top_n players
        vector::truncate(&mut leaderboard, top_n);
        leaderboard
    }

    public fun show_all_leaderboard(): vector<(address, u64)> {
        let state = borrow_global<State>(@0x1);
        let keys = table::keys(&state.points);
        let mut leaderboard = vector::empty<(address, u64)>();

        let len = vector::length(&keys);
        let mut i = 0;
        while (i < len) {
            let player = *vector::borrow(&keys, i);
            let points = *table::borrow(&state.points, player);
            vector::push_back(&mut leaderboard, (player, points));
            i = i + 1;
        }

        // sort the leaderboard by points in descending order
        vector::sort_by(&mut leaderboard, fun((a, b): &(address, u64), (c, d): &(address, u64)): bool {
            b > d
        });

        leaderboard
    }

    // testing funcs

    #[test]
    public fun test_create_room() {
        let account = @0x1;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account, room_name, bet_amount);

        let state = borrow_global<State>(signer::address_of(&account));
        let room_id = 0;
        let room = table::borrow(&state.rooms, room_id);

        assert!(room.creator == signer::address_of(&account), 201);
        assert!(room.bet_amount == bet_amount, 202);
        assert!(option::is_none(&room.player), 203);
        assert!(room.creator_ready, 204);
    }

    #[test]
    public fun test_join_room_by_id() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);

        let state = borrow_global<State>(signer::address_of(&account1));
        let room = table::borrow(&state.rooms, 0);

        assert!(option::is_some(&room.player), 301);
        assert!(*option::borrow(&room.player) == signer::address_of(&account2), 302);
    }

    #[test]
    public fun test_ready_by_room_id() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);
        ready(&account2, 0);

        let state = borrow_global<State>(signer::address_of(&account1));
        let room = table::borrow(&state.rooms, 0);

        assert!(room.creator_ready, 401);
        assert!(room.player_ready, 402);
    }

    #[test]
    public fun test_leave_room_by_id() {
        let account = @0x1;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account, room_name, bet_amount);

        let state = borrow_global<State>(signer::address_of(&account));
        let room_id = 0;
        leave_room(&account, room_id);

        assert!(!table::contains(&state.rooms, room_id), 501);
        assert!(!table::contains(&state.player_rooms, signer::address_of(&account)), 502);
    }

    #[test]
    public fun test_announce_winner() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);
        ready(&account2, 0);

        let winner = signer::address_of(&account1);
        announce_winner(&account1, 0, winner);

        let state = borrow_global<State>(signer::address_of(&account1));
        assert!(!table::contains(&state.rooms, 0), 601);
        let rewards = show_rewards(winner);
        assert!(rewards == 200, 602); // total pot is bet_amount * 2
    }

    #[test]
    public fun test_show_all_rooms() {
        let account = @0x1;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account, room_name, bet_amount);

        let rooms = show_all_rooms();
        assert!(vector::contains(&rooms, 0), 701);
    }

    #[test]
    public fun test_show_all_available_rooms() {
        let account = @0x1;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account, room_name, bet_amount);

        let available_rooms = show_all_available_rooms();
        assert!(vector::contains(&available_rooms, 0), 801);
    }

    #[test]
    public fun test_show_room_details() {
        let account1 = @0x1;
        let account2 = @0x2;
        let bet_amount = 100;
        let room_name = b"Test Room";
        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);
        ready(&account2, 0);

        let (name, creator, player, bet, creator_ready, player_ready) = show_room_details(0);

        assert!(name == room_name, 901);
        assert!(creator == signer::address_of(&account1), 902);
        assert!(option::is_some(&player) && *option::borrow(&player) == signer::address_of(&account2), 903);
        assert!(bet == bet_amount, 904);
        assert!(creator_ready, 905);
        assert!(player_ready, 906);
    }

     #[test]
    public fun test_show_leaderboard_by_top() {
        let account1 = @0x1;
        let account2 = @0x2;
        let account3 = @0x3;
        let bet_amount = 100;
        let room_name = b"Test Room";

        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);
        ready(&account2, 0);
        announce_winner(&account1, 0, signer::address_of(&account1));

        create_room(&account2, room_name, bet_amount);
        join_room(&account3, 1);
        ready(&account3, 1);
        announce_winner(&account2, 1, signer::address_of(&account2));

        create_room(&account1, room_name, bet_amount);
        join_room(&account3, 2);
        ready(&account3, 2);
        announce_winner(&account1, 2, signer::address_of(&account1));

        let leaderboard = show_leaderboard(3);
        assert!(vector::length(&leaderboard) == 3, 1001);
        assert!(vector::borrow(&leaderboard, 0)._1 == signer::address_of(&account1), 1002);
        assert!(vector::borrow(&leaderboard, 1)._1 == signer::address_of(&account2), 1003);
        assert!(vector::borrow(&leaderboard, 2)._1 == signer::address_of(&account3), 1004);
    }

    #[test]
    public fun test_show_all_leaderboard() {
        let account1 = @0x1;
        let account2 = @0x2;
        let account3 = @0x3;
        let bet_amount = 100;
        let room_name = b"Test Room";

        create_room(&account1, room_name, bet_amount);
        join_room(&account2, 0);
        ready(&account2, 0);
        announce_winner(&account1, 0, signer::address_of(&account1));

        create_room(&account2, room_name, bet_amount);
        join_room(&account3, 1);
        ready(&account3, 1);
        announce_winner(&account2, 1, signer::address_of(&account2));

        create_room(&account1, room_name, bet_amount);
        join_room(&account3, 2);
        ready(&account3, 2);
        announce_winner(&account1, 2, signer::address_of(&account1));

        let leaderboard = show_all_leaderboard();
        assert!(vector::length(&leaderboard) == 3, 1001);
        assert!(vector::borrow(&leaderboard, 0)._1 == signer::address_of(&account1), 1002);
        assert!(vector::borrow(&leaderboard, 1)._1 == signer::address_of(&account2), 1003);
        assert!(vector::borrow(&leaderboard, 2)._1 == signer::address_of(&account3), 1004);
    }
}
