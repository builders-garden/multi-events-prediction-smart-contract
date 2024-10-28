// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./IMultiEventsPrediction.sol";

contract MultiEventsPrediction is IMultiEventsPrediction, ERC1155Supply {

    //║══════════════════════════════════════════╗
    //║             Storage                      ║
    //║══════════════════════════════════════════╝
    
    /// @dev Maps prediction IDs to their corresponding Prediction struct
    mapping(uint256 => Prediction) public predictions;
    
    /// @dev Maps prediction IDs and outcome indices to their corresponding ERC1155 token IDs
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTokenIds;
    
    /// @dev Maps prediction IDs to arrays of outcome descriptions
    mapping(uint256 => string[]) public outcomesPrediction;
    
    /// @dev Maps prediction IDs to the winning outcome's token ID after resolution
    mapping(uint256 => uint256) public winningTokenId;

    /// @dev Address of the ERC20 token used for predictions (e.g., USDC)
    address public predictionTokenAddress;
    
    /// @dev Counter for prediction IDs, incremented for each new prediction
    uint256 public predictionId;
    
    /// @dev Counter for ERC1155 token IDs, incremented for each new outcome
    uint256 public lastOutcomeTokenId;
    
    /// @dev Address of the contract owner/admin
    address public owner;

    /// @dev Flag to pause/unpause contract functionality
    bool public paused;

    /// @dev SafeERC20 library usage for safe token transfers
    using SafeERC20 for IERC20;

    /**
     * @dev Modifier to restrict function access to contract owner only
     * @notice Reverts with UnauthorizedAccess if caller is not the owner
     */
    modifier onlyAdmin() {
        if (msg.sender != owner) revert UnauthorizedAccess();
        _;
    }

    /**
     * @dev Modifier to prevent function execution when contract is paused
     * @notice Reverts with ContractPaused if the contract is paused
     */
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // Constructor
    /**
     * @dev Initializes the contract with the default prediction token address.
     * @param _predictionTokenAddress The address of the ERC20 token to be used for predictions.
     */
    constructor(address _predictionTokenAddress, address _owner) ERC1155("") {
        predictionId = 0;
        lastOutcomeTokenId = 1;
        predictionTokenAddress = _predictionTokenAddress;
        owner = _owner;
    }

    //║══════════════════════════════════════════╗
    //║    Getters Functions                     ║
    //║══════════════════════════════════════════╝

    /**
     * @dev Returns the prediction and its outcomes for a given prediction ID.
     * @param id The ID of the prediction.
     * @return The Prediction struct and the array of outcome descriptions.
     */
    function getPrediction(uint256 id) public view returns (Prediction memory, string[] memory) {
        return (predictions[id], outcomesPrediction[id]);
    }

    /**
    * @dev Returns the total price for a specific amount of shares of a prediction outcome,
    * including handling the case where the total supply is zero without a loop.
    * @param id The ID of the prediction.
    * @param shareIdToken The ERC1155 tokenId of the outcome.
    * @param sharesAmount The number of shares to buy/sell.
    * @return The total price for the specified number of shares, including price impact.
    */
    function predictionSharePrice(
        uint256 id,
        uint256 shareIdToken,
        uint256 sharesAmount
    ) public view returns (uint256) {
        if (sharesAmount == 0) revert SharesAmountZero();

        Prediction storage prediction = predictions[id];
        if (prediction.admin == address(0)) revert PredictionDoesNotExist();

        if (prediction.status == PredictionStatus.CREATED) {
            // If there are no shares in circulation, it is virtual 1 share
            uint256 totalSharesAmount = prediction.totalSharesAmount; // 8
            uint256 totalSupplyOutcome = totalSupply(shareIdToken) > 0 ? totalSupply(shareIdToken) : 1; //1
            
            // Calculate the initial and final price per share
            uint256 initialPricePerShare = (totalSupplyOutcome * 10**6) / totalSharesAmount; // 1000000 / 8 = 125000
            uint256 newSupplyOutcome = totalSupplyOutcome + sharesAmount; // 1 + 5 = 6
            uint256 finalPricePerShare = (newSupplyOutcome * 10**6) / totalSharesAmount; // 6000000 / 8 = 750000

            // Use the average price between the initial and final price for all shares
            uint256 averagePricePerShare = (initialPricePerShare + finalPricePerShare) / 2; // (125000 + 750000) / 2 = 437500
            return averagePricePerShare * sharesAmount; // 437500 * 5 = 2187500

        } else if (prediction.status == PredictionStatus.RESOLVED) {
            uint256 winningOutcomeTokenId = winningTokenId[id];
            if (winningOutcomeTokenId == shareIdToken) {
                return 10**6 * sharesAmount; // 1 USDC per share * number of shares
            }
            return 0;
        }
        
        return 0;
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
    ) public whenNotPaused returns (uint256) {
        if (admin == address(0)) revert InvalidAdminAddress();
        if (outcomes.length <= 1) revert InsufficientOutcomes();
        
        predictionId++; // increment prediction ID

        predictions[predictionId] = Prediction({
            admin: admin,
            condition: condition,
            outcomeIndex: 0,
            totalSharesAmount: outcomes.length,
            initialSharesPrice: initialSharesPrice,
            status: PredictionStatus.CREATED
        });

        outcomesPrediction[predictionId] = outcomes;
        // Assign ERC1155 tokenId to each outcome starting from lastOutcomeTokenId
        for (uint256 i = 0; i < outcomes.length; i++) {
            outcomeTokenIds[predictionId][i] = lastOutcomeTokenId;
            lastOutcomeTokenId = lastOutcomeTokenId + 1;
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
        if (msg.sender != prediction.admin) revert NotPredictionAdmin();
        
        prediction.condition = condition;
        outcomesPrediction[id] = outcomes;
        
        emit PredictionMetadataChanged(id, condition);
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
    ) public whenNotPaused {
        if (sharesAmount == 0) revert SharesAmountZero();

        Prediction storage prediction = predictions[id];
        if (prediction.status != PredictionStatus.CREATED) revert PredictionAlreadyResolved();
        if (prediction.admin == address(0)) revert PredictionDoesNotExist();
        if (outcomeId >= outcomesPrediction[id].length) revert InvalidOutcomeId();

        IERC20 token = IERC20(predictionTokenAddress);

        uint256 amountToPay = 0;

        uint256 shareIdToken = outcomeTokenIds[id][outcomeId];
        uint256 sharePrice = predictionSharePrice(id, shareIdToken, sharesAmount);

        _mint(msg.sender, shareIdToken, sharesAmount, "");

        amountToPay += sharePrice;
        token.safeTransferFrom(msg.sender, address(this), amountToPay);

        prediction.totalSharesAmount += sharesAmount;

        emit PredictionSharesBought(id, msg.sender, shareIdToken, sharesAmount);
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
    ) public whenNotPaused{
        if (sharesAmount == 0) revert SharesAmountZero();
        if (outcomeId >= outcomesPrediction[id].length) revert InvalidOutcomeId();

        Prediction storage prediction = predictions[id];
        if (prediction.status != PredictionStatus.CREATED) revert PredictionAlreadyResolved();
        if (prediction.admin == address(0)) revert PredictionDoesNotExist();

        IERC20 token = IERC20(predictionTokenAddress);

        uint256 amountToReceive = 0;

        uint256 shareIdToken = outcomeTokenIds[id][outcomeId];
        uint256 sharePrice = predictionSharePrice(id, shareIdToken, sharesAmount);

        _burn(msg.sender, shareIdToken, sharesAmount);

        amountToReceive += sharePrice;
        token.safeTransfer(msg.sender, amountToReceive);

        prediction.totalSharesAmount -= sharesAmount;

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
    ) public whenNotPaused{
        if (sharesAmount == 0) revert SharesAmountZero();
        if (id == 0 || outcomeId == 0) revert InvalidPredictionOrOutcomeId();

        Prediction storage prediction = predictions[id];
        if (prediction.status != PredictionStatus.RESOLVED) revert PredictionNotResolvedYet();

        IERC20 token = IERC20(predictionTokenAddress);

        // Get the prediction share price for the winning outcome
        uint256 shareIdToken = outcomeTokenIds[id][outcomeId];
        uint256 sharePrice = predictionSharePrice(id, shareIdToken, sharesAmount);

        uint256 tokensAmount = sharesAmount * sharePrice;

        _burn(msg.sender, shareIdToken, sharesAmount);
        token.safeTransfer(msg.sender, tokensAmount);

        prediction.totalSharesAmount -= sharesAmount;

        emit PredictionSharesWithdrawn(id, msg.sender, outcomeId, sharesAmount);
    }

    /**
     * @dev Resolves a prediction by selecting the winning outcome and optionally distributing winnings.
     * @param id The ID of the prediction.
     * @param outcomeIndex The index of the winning outcome.
     */
    function resolvePrediction(
        uint256 id,
        uint256 outcomeIndex
    ) public {
        Prediction storage prediction = predictions[id];
        if (prediction.status != PredictionStatus.CREATED) revert PredictionAlreadyResolved();
        if (msg.sender != prediction.admin) revert NotPredictionAdmin();
        if (outcomeIndex >= outcomesPrediction[id].length) revert InvalidOutcomeId();
        if (outcomeTokenIds[id][outcomeIndex] == 0) revert InvalidOutcomeId();

        prediction.outcomeIndex = outcomeIndex;
        winningTokenId[id] = outcomeTokenIds[id][outcomeIndex];
        prediction.status = PredictionStatus.RESOLVED;

        emit PredictionResolved(id, outcomeIndex);
    }

    //║══════════════════════════════════════════╗
    //║    Admin Functions                      ║
    //║══════════════════════════════════════════╝

    /**
     * @dev Allows the contract owner to withdraw all tokens in case of emergency.
     * This function also pauses the contract to prevent further interactions.
     * @param recipient The address that will receive the withdrawn tokens
     * @notice This is an emergency function that should only be used in critical situations
     * @notice Emits an EmergencyWithdraw event
     */
    function emergencyWithdraw(address recipient) public onlyAdmin {
        IERC20 token = IERC20(predictionTokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(recipient, balance);
        paused = true;
        
        emit EmergencyWithdraw(recipient, balance);
    }

    /**
     * @dev Unpauses the contract, allowing normal operations to resume.
     * @notice Can only be called by the contract owner
     * @notice Emits a ContractUnpaused event
     */
    function unpause() public onlyAdmin {
        paused = false;
        emit ContractUnpaused();
    }

}
