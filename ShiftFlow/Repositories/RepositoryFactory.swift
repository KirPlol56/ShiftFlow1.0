//
//  RepositoryFactory.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//


import Foundation

/// Protocol that defines a repository provider
protocol RepositoryProvider {
    /// Get a repository for User entities
    func userRepository() -> any UserRepository
    
    /// Get a repository for Shift entities
    func shiftRepository() -> any ShiftRepository
    
    /// Get a repository for Role entities
    func roleRepository() -> any RoleRepository
    
    /// Get a repository for CheckList entities
    func checkListRepository() -> any CheckListRepository
}

/// Factory for creating repositories
class RepositoryFactory: RepositoryProvider {
    
    /// Singleton instance
    static let shared = RepositoryFactory()
    
    /// Private repositories - lazily initialized
    private lazy var _userRepository: any UserRepository = FirestoreUserRepository()
    private lazy var _shiftRepository: any ShiftRepository = FirestoreShiftRepository()
    private lazy var _roleRepository: any RoleRepository = FirestoreRoleRepository()
    private lazy var _checkListRepository: any CheckListRepository = FirestoreCheckListRepository()
    
    /// Private initializer for singleton
    private init() {}
    
    /// Get the User repository instance
    func userRepository() -> any UserRepository {
        return _userRepository
    }
    
    /// Get the Shift repository instance
    func shiftRepository() -> any ShiftRepository {
        return _shiftRepository
    }
    
    /// Get the Role repository instance
    func roleRepository() -> any RoleRepository {
        return _roleRepository
    }
    
    /// Get the CheckList repository instance
    func checkListRepository() -> any CheckListRepository {
        return _checkListRepository
    }
    
    /// Resets all repositories (mainly for testing purposes)
    func reset() {
        _userRepository = FirestoreUserRepository()
        _shiftRepository = FirestoreShiftRepository()
        _roleRepository = FirestoreRoleRepository()
        _checkListRepository = FirestoreCheckListRepository()
    }
}

/// Extension for testing with mock repositories
extension RepositoryFactory {
    
    /// Create a factory with mock repositories for testing
    static func createMockFactory(
        userRepository: any UserRepository = MockUserRepository(),
        shiftRepository: any ShiftRepository = MockShiftRepository(),
        roleRepository: any RoleRepository = MockRoleRepository(),
        checkListRepository: any CheckListRepository = MockCheckListRepository()
    ) -> RepositoryProvider {
        return MockRepositoryFactory(
            userRepository: userRepository,
            shiftRepository: shiftRepository,
            roleRepository: roleRepository,
            checkListRepository: checkListRepository
        )
    }
    
    /// Mock implementation of RepositoryProvider for testing
    private class MockRepositoryFactory: RepositoryProvider {
        private let _userRepository: any UserRepository
        private let _shiftRepository: any ShiftRepository
        private let _roleRepository: any RoleRepository
        private let _checkListRepository: any CheckListRepository
        
        init(
            userRepository: any UserRepository,
            shiftRepository: any ShiftRepository,
            roleRepository: any RoleRepository,
            checkListRepository: any CheckListRepository
        ) {
            self._userRepository = userRepository
            self._shiftRepository = shiftRepository
            self._roleRepository = roleRepository
            self._checkListRepository = checkListRepository
        }
        
        func userRepository() -> any UserRepository {
            return _userRepository
        }
        
        func shiftRepository() -> any ShiftRepository {
            return _shiftRepository
        }
        
        func roleRepository() -> any RoleRepository {
            return _roleRepository
        }
        
        func checkListRepository() -> any CheckListRepository {
            return _checkListRepository
        }
    }
}
