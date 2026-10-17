#ifndef IN_RANGE_NAIVE_HPP
#define IN_RANGE_NAIVE_HPP

template<typename T, T n, T m>
class InRange {
    using Self = InRange<T, n, m>;
public:
    InRange(T value) : x(value) {
        if (!check_constraint(value))
            throw 1;
    }
    Self& operator=(T value) {
        if (!check_constraint(value))
            throw 1;
        x = value;
        return *this;
    }

private:
    static bool check_constraint(T x) {
        return (x >= n && x < m);
    }
    T x;
};

#endif
