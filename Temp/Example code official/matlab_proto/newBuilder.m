function [ builder ] = newBuilder( classname )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
strings = cellstr(classname);
fullClassname = strcat('com.barra.openopt.protobuf$', strings{1});
builder = javaMethod('newBuilder', fullClassname);

end

