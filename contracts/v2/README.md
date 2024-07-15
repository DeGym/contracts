# V2 reasons

This version 2 handles multiples staking
The updated staking system consists of a central staking contract and user-specific staking contracts. This structure optimizes memory usage, enhances modularity, and isolates staking data per user, ensuring a flexible and secure reward distribution system.

## Explanation of Key Improvements

* *Modularity*: By separating user-specific staking logic into individual contracts, the system becomes more modular and easier to manage.
* *Memory Optimization*: Each user's staking data is isolated in their contract, reducing the load on the central contract.
* *Scalability*: This architecture supports scalability by allowing each user to interact with their contract independently, reducing potential bottlenecks.
* *Security*: Isolation of staking data per user enhances security and makes the system more resilient to potential issues.

This approach provides a robust and scalable solution for managing staking and rewards in the DeGym ecosystem.