// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../src/Diamond.sol";
import "../src/interfaces/IDiamondCut.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/OwnershipFacet.sol";
import "../src/facets/ERC721Facet.sol";
import "../src/facets/MerkleFacet.sol";
import "../src/facets/PresaleFacet.sol";

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;
    MerkleFacet merkleFacet;
    PresaleFacet presaleFacet;

    bytes32 public merkleRoot;
    address public owner;
    address public user1;
    address public user2;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721Facet = new ERC721Facet();
        merkleFacet = new MerkleFacet();
        presaleFacet = new PresaleFacet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](5);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(merkleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("MerkleFacet")
        });
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(presaleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("PresaleFacet")
        });
        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        // Set up test addresses
        owner = address(this);
        user1 = address(0x1111);
        user2 = address(0x2222);

        // Generate Merkle root from CSV file
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "scripts/generateMerkleRoot.js";
        bytes memory result = vm.ffi(inputs);
        merkleRoot = abi.decode(result, (bytes32));

        // Set Merkle root
        MerkleFacet(address(diamond)).setMerkleRoot(merkleRoot);

        // Set up presale parameters
        PresaleFacet(address(diamond)).setPresaleParameters(
            1 ether / 30,
            0.01 ether,
            1 ether
        );
    }

    function testDeployDiamond() public {
        //call a function to verify deployment
        address[] memory facetAddresses = DiamondLoupeFacet(address(diamond))
            .facetAddresses();
        assertEq(facetAddresses.length, 5); // Expecting 5 facets
    }

    function testMint() public {
        // Test minting through the merkle distributor
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "scripts/generateMerkleProof.js";
        inputs[2] = vm.toString(user1);
        inputs[3] = "merkle/addresses.csv";
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proof = abi.decode(result, (bytes32[]));

        vm.prank(user1);
        MerkleFacet(address(diamond)).claim(proof);
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 1);
    }

    function testPresale() public {
        // Test presale minting
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        PresaleFacet(address(diamond)).buyPresale{value: 0.1 ether}(3);
        assertEq(ERC721Facet(address(diamond)).balanceOf(user2), 3);
    }

    function testTransfer() public {
        // First, mint a token to user1
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "scripts/generateMerkleProof.js";
        inputs[2] = vm.toString(user1);
        inputs[3] = "merkle/addresses.csv";
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proof = abi.decode(result, (bytes32[]));

        vm.prank(user1);
        MerkleFacet(address(diamond)).claim(proof);

        // Now test ERC721 transfer
        vm.prank(user1);
        ERC721Facet(address(diamond)).transferFrom(user1, user2, 0);
        assertEq(ERC721Facet(address(diamond)).ownerOf(0), user2);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
