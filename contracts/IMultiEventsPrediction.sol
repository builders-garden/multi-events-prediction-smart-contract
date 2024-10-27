// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
interface IMultiEventsPrediction {
    // Custom Errors
    error InvalidAdminAddress();
    error InsufficientOutcomes();
    error InvalidPredictionId();
    error InvalidOutcomeId();
    error SharesAmountTooLow();
    error PredictionAlreadyResolved();
    error PredictionNotResolved();
    error NotPredictionAdmin();
    error ContractPaused();
    error PredictionDoesNotExist();
    error UnauthorizedAccess();
    error SharesAmountZero();
    error InvalidPredictionOrOutcomeId();
    error PredictionNotResolvedYet();

    enum PredictionStatus {
        CREATED,
        PAUSED,
        RESOLVED
    }

    struct Prediction {
        address admin;
        string condition;
        uint256 outcomeIndex;
        uint256 totalSharesAmount;
        uint256 initialSharesPrice;
        PredictionStatus status;
    }

    //║══════════════════════════════════════════╗
    //║              Events                      ║
    //║══════════════════════════════════════════╝
    event PredictionCreated(address admin, uint256 indexed predictionId);
    event PredictionSharesBought(uint256 indexed predictionId, address indexed player, uint256 outcomeId, uint256 sharesAmount);
    event PredictionSharesSold(uint256 indexed predictionId, address indexed player, uint256 outcomeId, uint256 sharesAmount);
    event PredictionSharesWithdrawn(uint256 indexed predictionId, address indexed player, uint256 outcomeId, uint256 sharesAmount);
    event PredictionResolved(uint256 indexed predictionId, uint256 indexed outcomeIndex);
    event PredictionMetadataChanged(uint256 indexed predictionId, string condition);
    event EmergencyWithdraw(address indexed recipient, uint256 amount);
    event ContractUnpaused();
}
