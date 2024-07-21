# Create form in 
## call

`create_room` 
```
account: &signer, //người tạo là người kí nên không cần nhập
room_name: vector<u8>,
bet_amount: u64,
```

## get

`get_all_rooms`
hiện tất cả phòng


`join_room_by_room_id`
```
account: &signer, //người join là người kí nên không cần nhập
room_id: u64,
```

`ready_by_room_id`
```
account: &signer, //người sẵn sàng là người kí nên không cần nhập
room_id: u64,
```

`leave_room_by_room_id`
```
account: &signer, //người rời phòng là người kí nên không cần nhập
room_id: u64,
```

`claim_winnings_by_room_id`
```
account: address, 
room_id: u64, 
winner: address
```

### Chỉ dành cho owner call khi nhận emit từ offchain để xác nhận ai là winner
`announce_winner_by_room_id`
```
signer: &signer, 
room_id: u64, 
winner: address
```

‎`show_all_available_rooms`
hiện tất cả phòng chưa có player2

`show_room_details_by_room_id`
hiện chi tiết một phòng theo id
```
room_id: u64
```

### update bot tracking sự kiện onchain

### update deploy telegram webapp && deploy to Erason web3 game marketplace on aptos eragon.gg/store/onchain-games

