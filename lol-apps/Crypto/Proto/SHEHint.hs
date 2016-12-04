{-# LANGUAGE BangPatterns, DeriveDataTypeable, DeriveGeneric, FlexibleInstances, MultiParamTypeClasses #-}
{-# OPTIONS_GHC  -fno-warn-unused-imports #-}
module Crypto.Proto.SHEHint (protoInfo, fileDescriptorProto) where
import Prelude ((+), (/))
import qualified Prelude as Prelude'
import qualified Data.Typeable as Prelude'
import qualified GHC.Generics as Prelude'
import qualified Data.Data as Prelude'
import qualified Text.ProtocolBuffers.Header as P'
import Text.DescriptorProtos.FileDescriptorProto (FileDescriptorProto)
import Text.ProtocolBuffers.Reflections (ProtoInfo)
import qualified Text.ProtocolBuffers.WireMessage as P' (wireGet,getFromBS)

protoInfo :: ProtoInfo
protoInfo
 = Prelude'.read
    "ProtoInfo {protoMod = ProtoName {protobufName = FIName \".SHEHint\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [], baseName = MName \"SHEHint\"}, protoFilePath = [\"Crypto\",\"Proto\",\"SHEHint.hs\"], protoSource = \"SHEHint.proto\", extensionKeys = fromList [], messages = [DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.LinearRq\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"LinearRq\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"LinearRq.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.LinearRq.e\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"LinearRq\"], baseName' = FName \"e\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 8}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 13}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.LinearRq.r\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"LinearRq\"], baseName' = FName \"r\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 2}, wireTag = WireTag {getWireTag = 16}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 13}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.LinearRq.coeffs\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"LinearRq\"], baseName' = FName \"coeffs\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 3}, wireTag = WireTag {getWireTag = 26}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".RLWE.Rq\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"RLWE\"], baseName = MName \"Rq\"}), hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.RqPolynomial\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"RqPolynomial\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"RqPolynomial.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.RqPolynomial.coeffs\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"RqPolynomial\"], baseName' = FName \"coeffs\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".RLWE.Rq\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"RLWE\"], baseName = MName \"Rq\"}), hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.KSLinearHint\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"KSLinearHint\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"KSLinearHint.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.KSLinearHint.hint\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"KSLinearHint\"], baseName' = FName \"hint\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.RqPolynomial\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"RqPolynomial\"}), hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.KSLinearHint.gad\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"KSLinearHint\"], baseName' = FName \"gad\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 2}, wireTag = WireTag {getWireTag = 18}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 9}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.KSQuadCircHint\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"KSQuadCircHint\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"KSQuadCircHint.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.KSQuadCircHint.hint\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"KSQuadCircHint\"], baseName' = FName \"hint\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.RqPolynomial\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"RqPolynomial\"}), hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.KSQuadCircHint.gad\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"KSQuadCircHint\"], baseName' = FName \"gad\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 2}, wireTag = WireTag {getWireTag = 18}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 9}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.TunnelHints\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"TunnelHints\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"TunnelHints.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.TunnelHints.coeffs\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"TunnelHints\"], baseName' = FName \"coeffs\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.LinearRq\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"LinearRq\"}), hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.TunnelHints.hint\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"TunnelHints\"], baseName' = FName \"hint\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 2}, wireTag = WireTag {getWireTag = 18}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.KSLinearHint\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"KSLinearHint\"}), hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.TunnelHints.p\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"TunnelHints\"], baseName' = FName \"p\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 3}, wireTag = WireTag {getWireTag = 24}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 4}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing},FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.TunnelHints.gad\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"TunnelHints\"], baseName' = FName \"gad\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 4}, wireTag = WireTag {getWireTag = 34}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = True, canRepeat = False, mightPack = False, typeCode = FieldType {getFieldType = 9}, typeName = Nothing, hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.TunnelHintChain\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"TunnelHintChain\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"TunnelHintChain.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.TunnelHintChain.hints\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"TunnelHintChain\"], baseName' = FName \"hints\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.TunnelHints\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"TunnelHints\"}), hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False},DescriptorInfo {descName = ProtoName {protobufName = FIName \".SHEHint.RoundHintChain\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"RoundHintChain\"}, descFilePath = [\"Crypto\",\"Proto\",\"SHEHint\",\"RoundHintChain.hs\"], isGroup = False, fields = fromList [FieldInfo {fieldName = ProtoFName {protobufName' = FIName \".SHEHint.RoundHintChain.hints\", haskellPrefix' = [MName \"Crypto\",MName \"Proto\"], parentModule' = [MName \"SHEHint\",MName \"RoundHintChain\"], baseName' = FName \"hints\", baseNamePrefix' = \"\"}, fieldNumber = FieldId {getFieldId = 1}, wireTag = WireTag {getWireTag = 10}, packedTag = Nothing, wireTagLength = 1, isPacked = False, isRequired = False, canRepeat = True, mightPack = False, typeCode = FieldType {getFieldType = 11}, typeName = Just (ProtoName {protobufName = FIName \".SHEHint.KSQuadCircHint\", haskellPrefix = [MName \"Crypto\",MName \"Proto\"], parentModule = [MName \"SHEHint\"], baseName = MName \"KSQuadCircHint\"}), hsRawDefault = Nothing, hsDefault = Nothing}], descOneofs = fromList [], keys = fromList [], extRanges = [], knownKeys = fromList [], storeUnknown = False, lazyFields = False, makeLenses = False}], enums = [], oneofs = [], knownKeyMap = fromList []}"

fileDescriptorProto :: FileDescriptorProto
fileDescriptorProto
 = P'.getFromBS (P'.wireGet 11)
    (P'.pack
      "\232\ETX\n\rSHEHint.proto\SUB\nRLWE.proto\":\n\bLinearRq\DC2\t\n\SOHe\CAN\SOH \STX(\r\DC2\t\n\SOHr\CAN\STX \STX(\r\DC2\CAN\n\ACKcoeffs\CAN\ETX \ETX(\v2\b.RLWE.Rq\"(\n\fRqPolynomial\DC2\CAN\n\ACKcoeffs\CAN\SOH \ETX(\v2\b.RLWE.Rq\"@\n\fKSLinearHint\DC2#\n\EOThint\CAN\SOH \ETX(\v2\NAK.SHEHint.RqPolynomial\DC2\v\n\ETXgad\CAN\STX \STX(\t\"B\n\SOKSQuadCircHint\DC2#\n\EOThint\CAN\SOH \ETX(\v2\NAK.SHEHint.RqPolynomial\DC2\v\n\ETXgad\CAN\STX \STX(\t\"m\n\vTunnelHints\DC2!\n\ACKcoeffs\CAN\SOH \STX(\v2\DC1.SHEHint.LinearRq\DC2#\n\EOThint\CAN\STX \ETX(\v2\NAK.SHEHint.KSLinearHint\DC2\t\n\SOHp\CAN\ETX \STX(\EOT\DC2\v\n\ETXgad\CAN\EOT \STX(\t\"6\n\SITunnelHintChain\DC2#\n\ENQhints\CAN\SOH \ETX(\v2\DC4.SHEHint.TunnelHints\"8\n\SORoundHintChain\DC2&\n\ENQhints\CAN\SOH \ETX(\v2\ETB.SHEHint.KSQuadCircHint")