import Foundation
import CoreData

extension FridgeItem {
    
    public var displayName: String {
        return name ?? "Unknown Item"
    }
    
    public var daysUntilExpiry: Int {
        guard let expiryDate = expiryDate else { return Int.max }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiry).day ?? Int.max
    }
    
    public var isExpiringSoon: Bool {
        return daysUntilExpiry <= 1 && daysUntilExpiry >= 0
    }
    
    public var isExpired: Bool {
        return daysUntilExpiry < 0
    }
    
    public var expiryStatus: ExpiryStatus {
        let days = daysUntilExpiry
        
        if days < 0 {
            return .expired
        } else if days == 0 {
            return .expiresToday
        } else if days == 1 {
            return .expiresTomorrow
        } else if days <= 3 {
            return .expiresSoon
        } else {
            return .fresh
        }
    }
    
    public var statusColor: String {
        switch expiryStatus {
        case .expired:
            return "red"
        case .expiresToday:
            return "orange"
        case .expiresTomorrow:
            return "yellow"
        case .expiresSoon:
            return "blue"
        case .fresh:
            return "green"
        }
    }
    
    public var statusText: String {
        switch expiryStatus {
        case .expired:
            return "Expired \(-daysUntilExpiry) day(s) ago"
        case .expiresToday:
            return "Expires today"
        case .expiresTomorrow:
            return "Expires tomorrow"
        case .expiresSoon:
            return "Expires in \(daysUntilExpiry) days"
        case .fresh:
            return "Fresh (\(daysUntilExpiry) days left)"
        }
    }
}

public enum ExpiryStatus {
    case expired
    case expiresToday
    case expiresTomorrow
    case expiresSoon
    case fresh
}