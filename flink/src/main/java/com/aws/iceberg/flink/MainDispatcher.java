// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink;

import com.amazonaws.services.kinesisanalytics.runtime.KinesisAnalyticsRuntime;

import java.lang.reflect.Method;
import java.util.Properties;

/**
 * Entry point for all Flink jobs in this fat JAR.
 *
 * Managed Flink requires a Main-Class in the JAR manifest. This dispatcher
 * reads the `main.class` property from the `FlinkApp` application property
 * group and delegates to the corresponding job's main() method.
 */
public final class MainDispatcher {

    public static void main(String[] args) throws Exception {
        Properties app = KinesisAnalyticsRuntime.getApplicationProperties()
                .getOrDefault("FlinkApp", new Properties());
        String mainClassName = app.getProperty("main.class");
        if (mainClassName == null || mainClassName.isBlank()) {
            throw new IllegalStateException(
                    "FlinkApp.main.class property is required but not set");
        }
        Class<?> mainClass = Class.forName(mainClassName); // nosemgrep: java.lang.security.audit.unsafe-reflection.unsafe-reflection
        Method mainMethod = mainClass.getMethod("main", String[].class);
        mainMethod.invoke(null, (Object) args);
    }
}
