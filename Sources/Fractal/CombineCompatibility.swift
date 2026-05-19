#if !canImport(Combine)
protocol ObservableObject: AnyObject {}

@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
#endif
