#include "devkit/circle.hpp"
#include <numbers>
#include <string>

namespace devkit {

Circle::Circle(double radius) : radius_(radius) {}

double Circle::Area() const {
    return std::numbers::pi * radius_ * radius_;
}

std::string Circle::Name() const {
    return "Circle";
}

}  // namespace devkit
