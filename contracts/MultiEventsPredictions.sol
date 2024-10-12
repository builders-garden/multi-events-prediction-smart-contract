// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract MultiEventsPredictions is ERC1155Supply {

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

    //║══════════════════════════════════════════╗
    //║             Storage                      ║
    //║══════════════════════════════════════════╝
    mapping(uint256 => Prediction) public predictions;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTokenIds; // predictionId => outcomeIndex => tokenId (ERC1155)
    mapping(uint256 => string[]) public outcomesPrediction;
    mapping(uint256 => uint256) public winningTokenId; // Stores the winning ERC1155 tokenId

    address public predictionTokenAddress; // e.g., USDC
    uint256 public predictionId;
    uint256 public lastOutcomeTokenId;

    using SafeERC20 for IERC20;

    // Constructor
    /**
     * @dev Initializes the contract with the default prediction token address.
     * @param _predictionTokenAddress The address of the ERC20 token to be used for predictions.
     */
    constructor(address _predictionTokenAddress) ERC1155("") {
        predictionId = 0;
        lastOutcomeTokenId = 0;
        predictionTokenAddress = _predictionTokenAddress;
    }

    //║══════════════════════════════════════════╗
    //║    Users Functions                       ║
    //║══════════════════════════════════════════╝

    /**
     * @dev Creates a new prediction with the specified parameters.
     * @param admin The address of the prediction admin.
     * @param condition The condition or description of the prediction.
     * @param outcomes The possible outcomes of the prediction.
     * @return The ID of the created prediction.
     */
    function createPrediction(
        address admin,
        string memory condition,
        string[] memory outcomes,
        uint256 initialSharesPrice
    ) public returns (uint256) {
        require(admin != address(0), "Invalid admin address");
        require(outcomes.length > 1, "At least 2 outcomes required");
        
        predictionId++; // increment prediction ID

        predictions[predictionId] = Prediction({
            admin: admin,
            condition: condition,
            outcomeIndex: 0,
            totalSharesAmount: 0,
            initialSharesPrice: initialSharesPrice,
            status: PredictionStatus.CREATED
        });

        outcomesPrediction[predictionId] = outcomes;
        // Assign ERC1155 tokenId to each outcome starting from lastOutcomeTokenId
        for (uint256 i = 0; i < outcomes.length; i++) {
            outcomeTokenIds[predictionId][i] = lastOutcomeTokenId + 1;
            lastOutcomeTokenId++;
        }

        emit PredictionCreated(admin, predictionId);
        return predictionId;
    }

    /**
     * @dev Allows the admin to change the prediction metadata.
     * @param id The ID of the prediction.
     * @param condition The updated condition or description of the prediction.
     * @param outcomes The updated possible outcomes of the prediction.
     */
    function changePredictionMetadata(
        uint256 id,
        string memory condition,
        string[] memory outcomes
    ) public {
        Prediction storage prediction = predictions[id];
        require(msg.sender == prediction.admin, "Only admin can change prediction metadata");
        prediction.condition = condition;
        outcomesPrediction[id] = outcomes;
    }

    /**
     * @dev Allows a user to buy prediction shares for a specific outcome.
     * @param id The ID of the prediction.
     * @param outcomeId The outcome to buy shares for.
     * @param sharesAmount The number of shares to buy.
     */
    function buyPredictionShares(
        uint256 id,
        uint256 outcomeId,
        uint256 sharesAmount
    ) public {
        require(sharesAmount > 0, "Shares amount must be greater than 0");
        require(id != 0 && outcomeId != 0, "Invalid predictionId or outcomeId");

        Prediction storage prediction = predictions[id];
        require(prediction.status == PredictionStatus.CREATED, "Prediction is already resolved");

        IERC20 token = IERC20(predictionTokenAddress);
        uint256 totalTokensAmount = 0;

        uint256 sharePrice = predictionSharePrice(id, outcomeId, sharesAmount);
        totalTokensAmount += sharePrice;
        prediction.totalSharesAmount += sharesAmount;
        _mint(msg.sender, outcomeId, sharesAmount, "");
        

        token.safeTransferFrom(msg.sender, address(this), totalTokensAmount);

        emit PredictionSharesBought(id, msg.sender, outcomeId, sharesAmount);
    }

    /**
     * @dev Allows a user to sell prediction shares for a specific outcome.
     * @param id The ID of the prediction.
     * @param outcomeId The outcome to sell shares for.
     * @param sharesAmount The number of shares to sell.
     */
    function sellPredictionShares(
        uint256 id,
        uint256 outcomeId,
        uint256 sharesAmount
    ) public {
        require(sharesAmount > 0, "Shares amount must be greater than 0");
        require(id != 0 && outcomeId != 0, "Invalid predictionId or outcomeId");

        Prediction storage prediction = predictions[id];
        require(prediction.status == PredictionStatus.CREATED, "Prediction is already resolved");

        IERC20 token = IERC20(predictionTokenAddress);
        uint256 totalTokensAmount = 0;

        uint256 sharePrice = predictionSharePrice(id, outcomeId, sharesAmount);
        totalTokensAmount += sharePrice;
        prediction.totalSharesAmount -= sharesAmount;
        _burn(msg.sender, outcomeId, sharesAmount);

        token.safeTransfer(msg.sender, totalTokensAmount);

        emit PredictionSharesSold(id, msg.sender, outcomeId, sharesAmount);
    }

    /**
     * @dev Allows a user to withdraw prediction shares after a prediction is resolved.
     * @param id The ID of the prediction.
     * @param outcomeId The outcome for which the shares are withdrawn.
     * @param sharesAmount The number of shares to withdraw.
     */
    function withdrawPredictionShares(
        uint256 id,
        uint256 outcomeId,
        uint256 sharesAmount
    ) public {
        require(sharesAmount > 0, "Shares amount must be greater than 0");
        require(id != 0 && outcomeId != 0, "Invalid predictionId or outcomeId");

        Prediction storage prediction = predictions[id];
        require(prediction.status == PredictionStatus.RESOLVED, "Prediction is not resolved yet");

        // Get the prediction share price for the winning outcome
        uint256 sharePrice = predictionSharePrice(id, outcomeId);
        uint256 tokensAmount = sharesAmount * sharePrice;

        _burn(msg.sender, outcomeId, sharesAmount);

        IERC20 token = IERC20(predictionTokenAddress);
        token.safeTransfer(msg.sender, tokensAmount);

        prediction.totalSharesAmount -= sharesAmount;

        emit PredictionSharesWithdrawn(id, msg.sender, outcomeId, sharesAmount);
    }

    /**
     * @dev Resolves a prediction by selecting the winning outcome and optionally distributing winnings.
     * @param id The ID of the prediction.
     * @param outcomeIndex The index of the winning outcome.
     * @param outcomeId The ERC1155 tokenId of the winning outcome.
     */
    function resolvePrediction(
        uint256 id,
        uint256 outcomeIndex,
        uint256 outcomeId
    ) public {
        Prediction storage prediction = predictions[id];
        require(prediction.status == PredictionStatus.CREATED, "Prediction is already resolved");
        require(msg.sender == prediction.admin, "Only admin can resolve the prediction");
        require(outcomeIndex < outcomesPrediction[id].length, "Invalid outcomeIndex");
        require(outcomeTokenIds[id][outcomeIndex] != 0, "Invalid outcomeId");

        prediction.outcomeIndex = outcomeIndex;
        winningTokenId[id] = outcomeId;
        prediction.status = PredictionStatus.RESOLVED;
    }

    /**
    * @dev Returns the total price for a specific amount of shares of a prediction outcome,
    * including handling the case where the total supply is zero without a loop.
    * @param id The ID of the prediction.
    * @param outcomeId The ERC1155 tokenId of the outcome.
    * @param sharesAmount The number of shares to buy/sell.
    * @return The total price for the specified number of shares, including price impact.
    */
    function predictionSharePrice(
        uint256 id,
        uint256 outcomeId,
        uint256 sharesAmount
    ) public view returns (uint256) {
        require(sharesAmount > 0, "Shares amount must be greater than zero");

        Prediction storage prediction = predictions[id];
        require(prediction.admin != address(0), "Prediction does not exist");

        if (prediction.status == PredictionStatus.CREATED) {
            uint256 totalSharesAmount = prediction.totalSharesAmount;
            uint256 totalSupplyOutcome = totalSupply(outcomeId);
            
            uint256 totalPrice = 0;

            if (totalSupplyOutcome > 0) {
                // Normal case when there are already shares in circulation
                uint256 initialPricePerShare = (totalSupplyOutcome * 10**6) / totalSharesAmount;
                uint256 newSupplyOutcome = totalSupplyOutcome + sharesAmount;
                uint256 finalPricePerShare = (newSupplyOutcome * 10**6) / totalSharesAmount;

                // Use the average price between the initial and final price for all shares
                uint256 averagePricePerShare = (initialPricePerShare + finalPricePerShare) / 2;
                return averagePricePerShare * sharesAmount;
            } else {
                
            }
        } else if (prediction.status == PredictionStatus.RESOLVED) {
            uint256 winningOutcomeTokenId = winningTokenId[id];
            if (winningOutcomeTokenId == outcomeId) {
                return 10**6 * sharesAmount; // 1 USDC per share * number of shares
            }
            return 0;
        }
        
        return 0;
    }


}
