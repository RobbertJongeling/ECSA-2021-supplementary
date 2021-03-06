/*
 * generated by Xtext 2.25.0
 */
package science.robbert.generator

import java.util.Arrays
import java.util.LinkedList
import java.util.List
import javax.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.naming.IQualifiedNameProvider
import science.robbert.tardisL.ASystem
import science.robbert.tardisL.Component
import science.robbert.tardisL.Configuration
import science.robbert.tardisL.IntervalOperator
import science.robbert.tardisL.SysCoordRef
import science.robbert.tardisL.SystemCoordinateLiteral
import science.robbert.tardisL.SystemVariant
import science.robbert.tardisL.SystemVersion
import science.robbert.tardisL.TemporalOperator
import science.robbert.tardisL.XExpression

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class TardisLGenerator extends AbstractGenerator {

	Resource gResource
	SystemVariant gVariant
	@Inject extension IQualifiedNameProvider
	
	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		gResource = resource

		//generate plantuml diagram	
		//fsa.generateFile(getSystemName(resource) + '.plantuml', generateSystems(resource))
		
				
		for (ASystem s : resource.allContents.toIterable.filter(ASystem)) {
			fsa.generateFile(
				s.fullyQualifiedName.toString("/") + ".plantuml",
				s.compile)
		}	
	}
		
		/*def compile(ASystem system) '''
			«system.systemVariants.map[createSystemVariant(it)].join»
		'''*/
		
		def compile(ASystem system) '''
			«FOR v : system.systemVariants»				
				«createSystemVariant(v)»
			«ENDFOR»
		'''
		
		//this «{ foo; "" }» is for supressing the output of the foo expression 
		//otherwise the evalutaion of foo would be printed, which we don't want
		//maybe this is ugly, but I don't know how to do it otherwise
		def createSystemVariant(SystemVariant variant) '''
			«{gVariant = variant; ""}»
			«IF variant.systemVersions.isEmpty»		
				@startuml
						
				package «variant.fullyQualifiedName» {
					«gResource.allContents.filter(Configuration).map[compile(variant, it)].join»
				}
				
				@enduml
			«ELSE»
				«FOR v : variant.systemVersions»
					«createSystemVersion(v)»
				«ENDFOR»
			«ENDIF»
		'''
		
		def createSystemVersion(SystemVersion version) '''
			@startuml
			
			package «version.fullyQualifiedName» {
				«gResource.allContents.filter(Configuration).map[compile(version, it)].join»
			}
			
			@enduml
		'''
		
		def compile(Component component) '''
			[«component.name»]
		'''
		
		/**
		 * Here, for each matching config (i.e. config exists in the current instance)
		 * make 3 entries:
		 * 	[comp] -( ri
			pi - [comp]
			ri ..> pi
			* 
			* We are for now ignoring the case of a component TODO implement cref ConfigurationOption
		 */
		def compile(SysCoordRef coord, Configuration config) '''
			«IF matches(coord, config.opt.atref.exp)»
				«val rs = config.opt.rref.ref.fullyQualifiedName.toString»
				«val ps = config.opt.pref.ref.fullyQualifiedName.toString»
				
				[«rs.substring(rs.indexOf(".")+1,rs.lastIndexOf("."))»] -( «config.opt.rref.ref.name»
				«config.opt.pref.ref.name» - [«ps.substring(ps.indexOf(".")+1,ps.lastIndexOf("."))»]
				«IF !(config.opt.rref.ref.name.toString.equals(config.opt.pref.ref.name.toString))»
					«config.opt.rref.ref.name» ..> «config.opt.pref.ref.name»
				«ENDIF»
			«ENDIF»
		'''
		
		def matches(SysCoordRef coord, XExpression exp) {
			//first handle the "ALL" case
			if(exp instanceof SystemCoordinateLiteral) {
				return true;
			} else {
				var allSystems = exp.interpret
				if(allSystems !== null) {
					return allSystems.contains(coord)				
				
				}
			}
			return false
		}
		
		def List<SysCoordRef> interpret(XExpression exp) {
			
			switch(exp) {
				SystemCoordinateLiteral: {
					Arrays.asList({exp.value.ref})
				}
				TemporalOperator: {
					
					val r = exp.tright.interpret as List<SysCoordRef>
					var List<SysCoordRef> toReturn = new LinkedList<SysCoordRef>()
					
					if(r!==null) {
						//for now assume only simple expressions, where each side is just a literal
						val r0 = r.get(0)						
						
						//for now we assume only 1 level, so only vars with revs.
						//therefore, we can be sure that r0 is a revision
						val allRevs = gVariant.systemVersions
						val index = allRevs.indexOf(r0)					

						if(index >= 0) {
							switch(exp.top) {
								case "<": {
									for (i : 0 ..< index) {
										toReturn.add(allRevs.get(i))
									}
								}
								case "<=": {
									for (i : 0 .. index) { 
										toReturn.add(allRevs.get(i))
									}
								}
								case ">=": {
									for (i : index ..< allRevs.size) {
										toReturn.add(allRevs.get(i))
									}
								}
								case ">": {
									for (i : index+1 ..< allRevs.size) {
										toReturn.add(allRevs.get(i))
									}
								}
							}
						}
					}
					
					toReturn
				}
				IntervalOperator: {
					var toReturn = new LinkedList<SysCoordRef>() 
					
					val left = exp.left.interpret as List<SysCoordRef>
					val right = exp.right.interpret as List<SysCoordRef>
					
					val allRevs = gVariant.systemVersions
					//assuming left and right are just literals
					//so that's why get(0)
										
					val indexL = allRevs.indexOf(left.get(0))
					val indexR = allRevs.indexOf(right.get(0))
										
					if(indexL >= 0 && indexR >= 0) {
						if(left !== null && right !== null) {
							for (i : indexL .. indexR) {
								toReturn.add(allRevs.get(i))
							}
						}
					}
					
					toReturn
				}
				XExpression: {
					Arrays.asList({exp.value.ref})	
				}							
			}
		}
}		
