@IsTest
private class JobRequestArgumentParserTest {
  @IsTest
  static void givenAllValidArguments_whenParse_thenValidListPopulatedAndNoErrors() {
    // Arrange
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ JobRequestArgumentParserTest.fakeRequest('{"k":"v"}'), JobRequestArgumentParserTest.fakeRequest('[1,2,3]') };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    // Act
    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    // Assert
    Assert.areEqual(2, result.validArguments.size(), 'Both requests should parse into validArguments');
    Assert.isTrue(result.malformedErrors.isEmpty(), 'No malformed errors expected');
  }

  @IsTest
  static void givenBlankArgument_whenParse_thenValidAsNull() {
    // Arrange
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ JobRequestArgumentParserTest.fakeRequest(null), JobRequestArgumentParserTest.fakeRequest('   ') };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    // Act
    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    // Assert
    Assert.areEqual(2, result.validArguments.size(), 'Blank argument is valid-as-null, not malformed');
    Assert.isNull(result.validArguments[0], 'null Argument__c should parse as null');
    Assert.isNull(result.validArguments[1], 'whitespace Argument__c should parse as null');
    Assert.isTrue(result.malformedErrors.isEmpty(), 'No malformed errors expected for blank arguments');
  }

  @IsTest
  static void givenMalformedJson_whenParse_thenMalformedErrorsPopulated() {
    // Arrange
    final JobRequest__c malformed = JobRequestArgumentParserTest.fakeRequest('{not valid json');
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ malformed };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    // Act
    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    // Assert
    Assert.isTrue(result.validArguments.isEmpty(), 'Malformed arguments must not appear in validArguments');
    Assert.areEqual(1, result.malformedErrors.size(), 'Exactly one malformed entry expected');
    Assert.isTrue(result.malformedErrors.containsKey(malformed.Id), 'Malformed entry keyed by the request Id');
    Assert.isTrue(String.isNotBlank(result.malformedErrors.get(malformed.Id)), 'Malformed entry value must carry the JSON parser error message');
  }

  @IsTest
  static void givenMixedChunk_whenParse_thenValidAndMalformedSplitCorrectly() {
    // Arrange
    final JobRequest__c valid = JobRequestArgumentParserTest.fakeRequest('{"ok":true}');
    final JobRequest__c malformed = JobRequestArgumentParserTest.fakeRequest('not-json');
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ valid, malformed };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    // Act
    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    // Assert
    Assert.areEqual(1, result.validArguments.size(), 'Exactly one valid argument');
    Assert.areEqual(1, result.malformedErrors.size(), 'Exactly one malformed entry');
    Assert.isTrue(result.malformedErrors.containsKey(malformed.Id), 'Malformed keyed by correct Id');
  }

  private static JobRequest__c fakeRequest(final String argument) {
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withArgument(argument).build();
    request.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    return request;
  }
}
