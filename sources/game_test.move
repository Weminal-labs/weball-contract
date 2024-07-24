// #[test_only]
// module admin::gamev3_tests {
//     use admin::gamev3;
//     use std::signer;
//     use aptos_framework::account;
//     use aptos_framework::coin;
//     use aptos_framework::aptos_coin::AptosCoin;
//     use std::string;
//     use std::vector;

//     fun create_test_account(): signer {
//         account::create_account_for_test(@0x1)
//     }

// #[test(admin = @admin)]
// public entry fun test_init_contract(admin: signer) {
//     account::create_account_for_test(@admin);
//     gamev3::init_contract(&admin);
//     assert!(vector::is_empty(&gamev3::get_all_rooms()), 0);
//     vector::destroy_empty(gamev3::get_all_rooms());
// }


//     #[test(admin = @admin, player1 = @0x123, aptos_framework = @aptos_framework)]
//     public entry fun test_create_room(admin: signer, player1: signer, aptos_framework: signer) {
//         gamev3::init_contract(&admin);

//         let player1_addr = signer::address_of(&player1);
//         account::create_account_for_test(player1_addr);
//         coin::register<AptosCoin>(&player1);
//         aptos_framework::aptos_coin::mint(&aptos_framework, player1_addr, 100000000);

//         let room_name = string::utf8(b"Test Room");
//         gamev3::create_room(&player1, room_name, 1000000);

//         let rooms = gamev3::get_all_rooms();
//         assert!(vector::length(&rooms) == 1, 0);

//         let (creator, _, _, _, bet_amount, _, _, _, _, _, _, _, _) = gamev3::room_detail_by_room_id(vector::length(&rooms));
//         assert!(creator == player1_addr, 1);
//         assert!(bet_amount == 1000000, 2);

//         vector::destroy_empty(rooms); // Drop the rooms vector
//     }

//     #[test(admin = @admin, player1 = @0x123, player2 = @0x456, aptos_framework = @aptos_framework)]
//     public entry fun test_join_room(admin: signer, player1: signer, player2: signer, aptos_framework: signer) {
//         gamev3::init_contract(&admin);
//         let player1_addr = signer::address_of(&player1);
//         let player2_addr = signer::address_of(&player2);
//         account::create_account_for_test(player1_addr);
//         account::create_account_for_test(player2_addr);
//         coin::register<AptosCoin>(&player1);
//         coin::register<AptosCoin>(&player2);
//         aptos_framework::aptos_coin::mint(&aptos_framework, player1_addr, 100000000);
//         aptos_framework::aptos_coin::mint(&aptos_framework, player2_addr, 100000000);

//         let room_name = string::utf8(b"Test Room");
//         gamev3::create_room(&player1, room_name, 1000000);

//         let rooms = gamev3::get_all_rooms();
//         let (_, room_id, _, _, _, _, _, _, _, _, _, _, _) = gamev3::room_detail_by_room_id(vector::length(&rooms));

//         gamev3::join_room_by_room_id(&player2, room_id);

//         let (_, _, _, _, _, _, is_player2_joined, player2_option, _, _, _, _, _) = gamev3::room_detail_by_room_id(room_id);
//         assert!(is_player2_joined == true, 0);
//         assert!(std::option::contains(&player2_option, &player2_addr), 1);

//         vector::destroy_empty(rooms); // Drop the rooms vector
//     }

//     #[test(admin = @admin, player1 = @0x123, player2 = @0x456, aptos_framework = @aptos_framework)]
//     public entry fun test_pick_winner(admin: signer, player1: signer, player2: signer, aptos_framework: signer) {
//         gamev3::init_contract(&admin);
//         let player1_addr = signer::address_of(&player1);
//         let player2_addr = signer::address_of(&player2);
//         account::create_account_for_test(player1_addr);
//         account::create_account_for_test(player2_addr);
//         coin::register<AptosCoin>(&player1);
//         coin::register<AptosCoin>(&player2);
//         aptos_framework::aptos_coin::mint(&aptos_framework, player1_addr, 100000000);
//         aptos_framework::aptos_coin::mint(&aptos_framework, player2_addr, 100000000);

//         let room_name = string::utf8(b"Test Room");
//         gamev3::create_room(&player1, room_name, 1000000);

//         let rooms = gamev3::get_all_rooms();
//         let (_, room_id, _, _, _, _, _, _, _, _, _, _, _) = gamev3::room_detail_by_room_id(vector::length(&rooms));
//         gamev3::join_room_by_room_id(&player2, room_id);

//         gamev3::pick_winner_and_transfer_bet(&admin, room_id, player2_addr);

//         let (_, _, _, _, _, _, _, _, _, is_room_close, _, _, winner_option) = gamev3::room_detail_by_room_id(room_id);
//         assert!(is_room_close == true, 0);
//         assert!(std::option::contains(&winner_option, &player2_addr), 1);

//         let winner_balance = coin::balance<AptosCoin>(player2_addr);
//         assert!(winner_balance == 102000000, 2);

//         vector::destroy_empty(rooms); // Drop the rooms vector
//     }
// }


