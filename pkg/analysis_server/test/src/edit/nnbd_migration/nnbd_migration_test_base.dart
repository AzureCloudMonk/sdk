// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/edit/fix/dartfix_listener.dart';
import 'package:analysis_server/src/edit/fix/non_nullable_fix.dart';
import 'package:analysis_server/src/edit/nnbd_migration/info_builder.dart';
import 'package:analysis_server/src/edit/nnbd_migration/instrumentation_information.dart';
import 'package:analysis_server/src/edit/nnbd_migration/instrumentation_listener.dart';
import 'package:analysis_server/src/edit/nnbd_migration/migration_info.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../analysis_abstract.dart';

@reflectiveTest
class NnbdMigrationTestBase extends AbstractAnalysisTest {
  /// The information produced by the InfoBuilder, or `null` if [buildInfo] has
  /// not yet completed.
  Set<UnitInfo> infos;

  /// Use the InfoBuilder to build information. The information will be stored
  /// in [infos].
  Future<void> buildInfo() async {
    // Compute the analysis results.
    String includedRoot = resourceProvider.pathContext.dirname(testFile);
    server.setAnalysisRoots('0', [includedRoot], [], {});
    var result = await server
        .getAnalysisDriver(testFile)
        .currentSession
        .getResolvedUnit(testFile);
    // Run the migration engine.
    DartFixListener listener = DartFixListener(server);
    InstrumentationListener instrumentationListener = InstrumentationListener();
    NullabilityMigration migration = NullabilityMigration(
        NullabilityMigrationAdapter(listener),
        permissive: false,
        instrumentation: instrumentationListener);
    migration.prepareInput(result);
    migration.processInput(result);
    migration.finalizeInput(result);
    migration.finish();
    // Build the migration info.
    InstrumentationInformation info = instrumentationListener.data;
    InfoBuilder builder = InfoBuilder(
        resourceProvider, includedRoot, info, listener,
        explainNonNullableTypes: true);
    infos = await builder.explainMigration();
  }

  /// Uses the InfoBuilder to build information for a single test file.
  ///
  /// Asserts that [originalContent] is migrated to [migratedContent]. Returns
  /// the singular UnitInfo which was built.
  Future<UnitInfo> buildInfoForSingleTestFile(String originalContent,
      {@required String migratedContent}) async {
    addTestFile(originalContent);
    await buildInfo();
    // Ignore info for dart:core.
    var filteredInfos = [
      for (var info in infos) if (info.path.indexOf('core.dart') == -1) info
    ];
    expect(filteredInfos, hasLength(1));
    UnitInfo unit = filteredInfos[0];
    expect(unit.path, testFile);
    expect(unit.content, migratedContent);
    return unit;
  }
}
