import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("MultiEventPrediction", function () {
  async function deployMultiEventPrediction() {
    const [owner, otherAccount] = await ethers.getSigners();

    const MultiEventsPrediction = await ethers.getContractFactory("MultiEventsPrediction");
    const usdcAddress = "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"; // USDC on Base
    const multiEventPrediction = await MultiEventsPrediction.deploy(usdcAddress, owner.address);

    const usdc = await ethers.getContractAt("IERC20", usdcAddress);

    // USDC Base holders addresses
    const baseHolder1 = "0xe36288736e5a45c27ee6FA2F8d1A1aeD99D3eA63";
    const baseHolder2 = "0x97e8418bE37bb4145f4Fc67266D0cb0761cb48A0";
    const baseHolder3 = "0xaBe8fE965CaAfA63a4537B30eAebe4B97Af52e43";
    const baseHolder4 = "0xe423F4d8d786939fe131Df85A61193afF0370AA9";
    const baseHolder5 = "0x94d5Dec1796404ff3544FB09461AF0bC3fb3c2F6";
    const baseHolder6 = "0xa0e72f85D3ab3920e6Bb17109819Ea7E07Fcf7CF";
    const baseHolder7 = "0x8F1901DcEf5F7b6E2502F1052AfB589F1734F565";
    const baseHolder8 = "0x7Ee7D91E3C4fdDb9AA5Efe0e68F0e40A92A16D93";
    const baseHolder9 = "0xD702F51Fa5a667Ca70440cd3df8DAC53534D1cac";
    const baseHolder10 = "0x05e189E1BbaF77f1654F0983872fd938AE592eDD";


    return { multiEventPrediction, owner, otherAccount, usdc, usdcAddress, baseHolder1, baseHolder2, baseHolder3, baseHolder4, baseHolder5, baseHolder6, baseHolder7, baseHolder8, baseHolder9, baseHolder10 };
  }

  describe("Deployment", function () {
    it("Should set the correct prediction token address", async function () {
      const { multiEventPrediction, usdcAddress } = await loadFixture(deployMultiEventPrediction);
      expect((await multiEventPrediction.predictionTokenAddress()).toLowerCase()).to.equal(usdcAddress.toLowerCase());
    });
  });

  describe("Create Prediction", function () {
    it("Should create a prediction", async function () {
      const { multiEventPrediction, owner } = await loadFixture(deployMultiEventPrediction);
      await multiEventPrediction.connect(owner).createPrediction(owner.address, "Prediction 1", ["Outcome 1", "Outcome 2"], 1000000);
      const predictionId = await multiEventPrediction.predictionId();
      expect(predictionId).to.equal(1);
      const prediction = await multiEventPrediction.predictions(BigInt(predictionId));
      const [, outcomesPrediction] = await multiEventPrediction.getPrediction(predictionId);
      expect(prediction.admin).to.equal(owner.address);
      expect(prediction.condition).to.equal("Prediction 1");
      expect(prediction.initialSharesPrice).to.equal(1000000);
      expect(outcomesPrediction[0]).to.equal("Outcome 1");
      expect(outcomesPrediction[1]).to.equal("Outcome 2");
    });
  });

  describe("Scenario 1", function () {
    it("Simulate a prediction with 8 outcomes", async function () {
        const { multiEventPrediction, owner, usdc, baseHolder1, baseHolder2, baseHolder3, baseHolder4, baseHolder5, baseHolder6, baseHolder7, baseHolder8, baseHolder9, baseHolder10 } = await loadFixture(deployMultiEventPrediction);

        // Create signers for all players
        const signers = await Promise.all([
            ethers.getImpersonatedSigner(baseHolder1),
            ethers.getImpersonatedSigner(baseHolder2),
            ethers.getImpersonatedSigner(baseHolder3),
            ethers.getImpersonatedSigner(baseHolder4),
            ethers.getImpersonatedSigner(baseHolder5),
            ethers.getImpersonatedSigner(baseHolder6),
            ethers.getImpersonatedSigner(baseHolder7),
            ethers.getImpersonatedSigner(baseHolder8),
            ethers.getImpersonatedSigner(baseHolder9),
            ethers.getImpersonatedSigner(baseHolder10),
        ]);

        // Create prediction with 8 outcomes
        const outcomes = [
            "Outcome 1",
            "Outcome 2",
            "Outcome 3",
            "Outcome 4",
            "Outcome 5",
            "Outcome 6",
            "Outcome 7",
            "Outcome 8"
        ];
        
        await multiEventPrediction.createPrediction(
            owner.address,
            "Which team will win the tournament?",
            outcomes,
            125000 // 1 USDC initial price
        );

        console.log("Prediction created");

        const lastOutcomeTokenId = await multiEventPrediction.lastOutcomeTokenId();
        console.log("lastOutcomeTokenId", lastOutcomeTokenId);

        // Distribution of bets (uneven to test price impact)
        const bets = [
            { signer: 0, outcome: 0, amount: 1 },  // Player 1 bets 5 shares on outcome 1
            { signer: 1, outcome: 1, amount: 1 },  // Player 2 bets 3 shares on outcome 1
            { signer: 2, outcome: 2, amount: 1 },  // Player 3 bets 4 shares on outcome 2
            { signer: 3, outcome: 3, amount: 1 },  // Player 4 bets 2 shares on outcome 3
            { signer: 4, outcome: 4, amount: 1 },  // Player 5 bets 6 shares on outcome 4
            { signer: 5, outcome: 5, amount: 1 },  // Player 6 bets 3 shares on outcome 5
            { signer: 6, outcome: 6, amount: 1 },  // Player 7 bets 4 shares on outcome 6
            { signer: 7, outcome: 7, amount: 1 },  // Player 8 bets 2 shares on outcome 7
            { signer: 8, outcome: 8, amount: 1 },  // Player 9 bets 5 shares on outcome 8
            { signer: 9, outcome: 9, amount: 1 },  // Player 10 bets 3 shares on outcome 9
        ];

        console.log("\nPlacing bets...");
        
        // Place all bets
        for (const bet of bets) {
            const signer = signers[bet.signer];
            console.log("signer", signer.address);
            const outcomeId = bet.outcome;
            console.log("outcomeId", outcomeId);
            const sharesAmount = bet.amount;
            console.log("sharesAmount", sharesAmount);

            // Get price before bet
            const shareIdToken = await multiEventPrediction.outcomeTokenIds(1, outcomeId);
            console.log("shareIdToken", shareIdToken);
            const priceBeforeBet = await multiEventPrediction.predictionSharePrice(1, shareIdToken, sharesAmount);
            console.log("priceBeforeBet", priceBeforeBet);
            const priceFor1Share = await multiEventPrediction.predictionSharePrice(1, shareIdToken, 1);
            console.log("priceFor1Share", ethers.formatUnits(priceFor1Share, 6));

            // log sum of all shares price
            let sum = BigInt(0);  // Initialize as BigInt
            for (let i = 1; i <= outcomes.length; i++) {
                const price = await multiEventPrediction.predictionSharePrice(1, BigInt(i), 1);
                sum += price;  // Now both are BigInt
            }
            console.log("sum", ethers.formatUnits(sum, 6));
            
            // Approve and place bet
            await usdc.connect(signer).approve(multiEventPrediction.target, priceBeforeBet);
            console.log("Bet approved");
            await multiEventPrediction.connect(signer).buyPredictionShares(1, outcomeId, sharesAmount);

            console.log(`Player ${bet.signer + 1} bet ${sharesAmount} shares on outcome ${outcomeId + 1} for ${ethers.formatUnits(priceBeforeBet, 6)} USDC. The share price is ${ethers.formatUnits(priceBeforeBet, 6)}`);
        }

        // Wait some time (optional in test but good practice)
        await time.increase(3600); // 1 hour

        // Resolve prediction (let's say outcome 3 wins - index 2)
        const winningOutcome = 2;
        await multiEventPrediction.connect(owner).resolvePrediction(1, winningOutcome);
        console.log(`\nPrediction resolved. Outcome ${winningOutcome + 1} wins!`);

        //check price is 1 for winning outcome
        const shareIdToken = await multiEventPrediction.outcomeTokenIds(1, winningOutcome);
        console.log("shareIdToken", shareIdToken);
        const price = await multiEventPrediction.predictionSharePrice(1, shareIdToken, 1);
        console.log("price", price);
        expect(price).to.equal(1000000);

        // Winners withdraw their winnings
        const winners = bets.filter(bet => bet.outcome === winningOutcome);
        console.log("\nWinners withdrawing...");

        for (let i = 0; i < winners.length; i++) {
            const winner = winners[i];
            const signer = signers[winner.signer];
            const contractBalance = await usdc.balanceOf(multiEventPrediction.target);
            console.log("contractBalance", contractBalance);
            const balanceBefore = await usdc.balanceOf(signer.address);
            console.log("balanceBefore", balanceBefore);
            // If this is the last winner, withdraw all remaining shares
            if (i === winners.length - 1) {
                const remainingShares = await multiEventPrediction.balanceOf(signer.address, await multiEventPrediction.outcomeTokenIds(1, winningOutcome));
                await multiEventPrediction.connect(signer).withdrawPredictionShares(1, winningOutcome, remainingShares);
            } else {
                await multiEventPrediction.connect(signer).withdrawPredictionShares(1, winningOutcome, winner.amount);
            }
            
            const balanceAfter = await usdc.balanceOf(signer.address);
            const contractBalanceAfter = await usdc.balanceOf(multiEventPrediction.target);
            const profit = balanceAfter - balanceBefore;
            console.log("balanceAfter", balanceAfter);
            console.log("contractBalanceAfter", contractBalanceAfter);
            console.log(`Player ${winner.signer + 1} withdrew ${winner.amount} shares and received ${ethers.formatUnits(profit, 6)} USDC`);
        }

        // Verify final state
        const prediction = await multiEventPrediction.predictions(1);
        expect(prediction.status).to.equal(2); // RESOLVED
        expect(prediction.outcomeIndex).to.equal(winningOutcome);
    });
  });
});
