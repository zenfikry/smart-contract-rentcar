// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.0;

contract CarRent {
    address payable public owner;

    uint public countCar = 0;
    uint public countRentAgreement = 0;

    enum CarStatus {AVAILABLE, NOT_AVAILABLE}
    enum CarType {HATCHBACK, MPV, SUV}

    constructor() {
        owner = msg.sender;
    }

    struct Car {
        uint carId;
        string carName;
        string carBrand;
        CarType carType;
        uint rentFee;
        uint penaltyFee;
        CarStatus carStatus;
        uint currentRentAgreementId;
        address payable currentRenter;
    }
    mapping(uint => Car) public Cars;

    struct RentAgreement {
        uint rentAgreementId;
        uint carId;
        string carName;
        string carBrand;
        uint rentFee;
        uint penaltyFee;
        address payable carRenter;
        uint timestamp;
        uint rentPeriod;
        bool isGetPenalty;
        bool isPenaltyPaid;
        bool isAgreementCompleted;
    }
    mapping(uint => RentAgreement) public RentAgreements;

    modifier isOwner {
        require (owner == msg.sender, "You are not owner");
        _;
    }

    modifier isNotOwner {
        require (owner != msg.sender, "You are not renter");
        _;
    }

    modifier isSameRenter(uint _carId) {
        require(msg.sender == Cars[_carId].currentRenter, "You are not current renter");
        _;
    }

    modifier isCarAvailable(uint _carId) {
        require(Cars[_carId].carStatus == CarStatus.AVAILABLE, "The car is not available");
        _;
    }

    modifier rentFeeCheck(uint _carId, uint _rentPeriod) {
        uint totalFee = Cars[_carId].rentFee * _rentPeriod * (1 ether);
        require(msg.value >= totalFee, "Not enough Ether to pay rent fee");
        _;
    }

    modifier penaltyCheck(uint _carId) {
        uint currentRentAgreementId = Cars[_carId].currentRentAgreementId;
        RentAgreement memory agreement = RentAgreements[currentRentAgreementId];
        // uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 days);
        uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 minutes);
        require(block.timestamp <= dueDate || (agreement.isGetPenalty == true && agreement.isPenaltyPaid == true), "Your agreement is expired. Please pay for penalty");
        _;
    }

    modifier isAgreementExpired(uint _carId) {
        uint currentRentAgreementId = Cars[_carId].currentRentAgreementId;
        RentAgreement memory agreement = RentAgreements[currentRentAgreementId];
        // uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 days);
        uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 minutes);
        require(block.timestamp > dueDate, "You still have time for this car");
        _;
    }

    function addCar(string memory _carName, string memory _carBrand, CarType _carType, uint _rentFee, uint _penaltyFee) external isOwner {
        countCar++;
        Cars[countCar] = Car(countCar, _carName, _carBrand, _carType, _rentFee, _penaltyFee, CarStatus.AVAILABLE, 0, address(0));
    }

    event eventRentCar(uint _carId, address _carRenter, uint _rentFee);

    function rentCar(uint _carId, uint _rentPeriod) external payable isNotOwner isCarAvailable(_carId) rentFeeCheck(_carId, _rentPeriod) {
        // get car data
        Car memory car = Cars[_carId];

        // create rent agreement
        countRentAgreement++;
        RentAgreements[countRentAgreement] = RentAgreement(countRentAgreement, _carId, car.carName, car.carBrand, car.rentFee, car.penaltyFee, msg.sender, block.timestamp, _rentPeriod, false, false, false);

        // update car data
        Cars[_carId].carStatus = CarStatus.NOT_AVAILABLE;
        Cars[_carId].currentRentAgreementId = countRentAgreement;
        Cars[_carId].currentRenter = msg.sender;

        owner.transfer(msg.value);
        emit eventRentCar(_carId, msg.sender, msg.value);
    }

    function returnCar(uint _carId) external isSameRenter(_carId) penaltyCheck(_carId) {
        uint currentRentAgreementId = Cars[_carId].currentRentAgreementId;
        // set flag agreement status
        RentAgreements[currentRentAgreementId].isAgreementCompleted = true;

        // reset car data
        Cars[_carId].carStatus = CarStatus.AVAILABLE;
        Cars[_carId].currentRentAgreementId = 0;
        Cars[_carId].currentRenter = address(0);
    }

    function payPenalty(uint _carId) external payable isSameRenter(_carId) isAgreementExpired(_carId) {
        uint currentRentAgreementId = Cars[_carId].currentRentAgreementId;

        // set flag get penalty
        RentAgreements[currentRentAgreementId].isGetPenalty = true;

        uint penaltyFee = Cars[_carId].penaltyFee * (1 ether);
        require(msg.value >= penaltyFee, "Not enough Ether to pay penalty");
        owner.transfer(msg.value);
        RentAgreements[currentRentAgreementId].isPenaltyPaid = true;
    }
}