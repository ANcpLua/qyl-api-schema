import {assertInvalid,assertValid,contractSchema,validatorFor} from './lib/contract-fixtures.mjs';
import {readOpenApi} from './lib/openapi.mjs';
const names=['Triage','ListFailures','GetFailureContext','CompareGroups','CompareTraces','VerifyFix','AggregateTelemetry','DiscoverAttributes','GetAgentRun','ListReleases','GetServiceMap','CheckTelemetryHealth','GetMcpStats','ListSessions','ListTraces','GetTrace','SearchLogs','ListMetrics','GetMetricSeries','QueryMetric','CiLog','ListSavedQueries','RunSavedQuery','DisplayTraces','DisplayMcpDashboard','FetchTelemetry'];
const openapi=await readOpenApi();
for(const name of names){
 const key=name.replace(/[A-Z]/g,(c,i)=>(i?'_':'')+c.toLowerCase());
 const op=openapi.paths[`/api/v1/analysis/${key}`]?.post;
 if(!op)throw Error(`Missing read operation ${key}`);
 for(const suffix of ['Input','Output'])if(contractSchema.$defs[`Mcp.Tools.${name}${suffix}`]?.type!=='object')throw Error(`Missing object schema ${name}${suffix}`);
 const out=contractSchema.$defs[`Mcp.Tools.${name}Output`];
 for(const key of ['window','coverage'])if(!out.required?.includes(key))throw Error(`${name} does not require ${key}`);
}
const V=n=>validatorFor(`Mcp.Tools.${n}`), C=n=>validatorFor(`Common.${n}`);
const trace='0123456789abcdef0123456789abcdef',span='0123456789abcdef',at='2026-10-12T10:00:00Z';
const window={start_time:'2026-10-12T09:00:00Z',end_time:at};
const coverage={examined:40,matched:40,returned:1,truncated:false,scan_complete:true,as_of:at};
const read={window,coverage,has_more:false};
const failure={failure_id:'opaque-project-F',etag:'v1',signature:'orders-db|query|timeout',normalized_message:'timeout',operation:'query',service:'orders-db',first_seen:at,last_seen:at,count:3,affected_traces:3,affected_sessions:1,releases_seen:['1.4.1'],status:'open',updated_at:at,annotation_count:0,example_trace_ids:[trace]};
const tf={failure_id:failure.failure_id,signature:failure.signature,change:'new',count:3,baseline_count:0,affected_traces:3,services:['orders-db'],first_seen:at,coinciding_release:{service:'orders-db',version:'1.4.1',first_seen:at}};
const es={trace_id:trace,span_id:span,service:'orders-db',name:'db.query',status:'ERROR',key_attributes:[],duration_ms:5,role:'matched'};
const divergence={a_span:es,b_span:{...es,status:'OK'},kind:'status'};
const totals={requests:40,errors:8,error_rate:.2,p50_ms:100,p95_ms:300,unit:'requests'};
const group={...totals,name:'search_logs',example_trace_ids:[trace]};
const classes={transport:0,protocol:0,tool_result:0,authentication:0,cancellation:0,timeout:8};
/** @type {Array<[string, Record<string, unknown>, string]>} */
const cases=[
 ['TriageOutput',{...read,failures:[tf,{...tf,failure_id:'opaque-project-R',count:2}],regressions:[],releases:[tf.coinciding_release],silent_services:[{service:'billing',last_seen:'2026-10-12T08:00:00Z',usual_rate:1,unit:'spans/minute'}]},'triage F first, rare R retained, billing silent'],
 ['ListFailuresOutput',{...read,failures:[failure,{...failure,failure_id:'opaque-checkout',service:'checkout'}],has_more:false},'db chain exactly two stable failure records'],
 ['GetFailureContextOutput',{...read,observed:{root_cause_span:es,error_spans:[es],propagation:[],logs:[],retries:[],fanout:[]},comparison:{first_divergence:divergence,nearest_success_trace_id:trace},context:{similar_failures:[],changes:[],annotations:[]},settled:false,unknowns:[]},'db root evidence and unsettled arrival'],
 ['CompareGroupsOutput',{...read,discriminators:[{key:'cloud.region',value:'eu',share_a:1,share_b:.5,count_a:10,count_b:5,lift:2},{key:'app.version',value:'2.3',share_a:1,share_b:.5,count_a:10,count_b:5,lift:2}],structural:[],durations:{a:{p50_ms:2,p95_ms:3,p99_ms:4},b:{p50_ms:1,p95_ms:2,p99_ms:3}},composition:{changed:true,traffic_mix_changed:false,same_traffic_changed:true,summary:'Association'},size_a:10,size_b:10,excluded_keys:[]},'eu and version discriminator evidence'],
 ['CompareTracesOutput',{...read,first_divergence:divergence,aligned:[{a_span:es,b_span:es,differences:[divergence]}],after_divergence:[],unmatched:[],comparable:true},'db status divergence'],
 ['VerifyFixOutput',{...read,verdict:'pending',before:{window,occurrences:3,requests:100,rate:.03,unit:'requests'},after:{window,occurrences:0,requests:4,rate:0,unit:'requests'},needs:{requests:96,minutes:25},recurrences:[],guardrails:[],verify_id:'signed-project-token'},'fix with four requests needs ninety-six'],
 ['AggregateTelemetryOutput',{...read,groups:[{key:{'http.route':'/checkout'},measures:{duration_p95:1840},buckets:[]},{key:{'gen_ai.tool.name':'search_logs'},measures:{count:40,error_count:8,error_rate:.2}}],other:{groups:0,count:0},units:{count:'spans',duration_p95:'ms',error_rate:'ratio'}},'route latency and MCP denominator'],
 ['DiscoverAttributesOutput',{...read,attributes:[{key:'cloud.region',scope:'resource',type:'string',coverage_share:1,cardinality:2,cardinality_exact:true,top_values:[{value:'eu',count:10,share:.5}],semconv:{brief:'Cloud region.',stability:'stable',requirement_level:'recommended'}}]},'region cardinality and semantic brief'],
 ['GetAgentRunOutput',{...read,run:{agent_name:'agent',models:['model'],started:at,duration_ms:4,tokens:{input:10,output:20,cache_read:null,cache_write:null,reasoning:null},errors:0},steps:[],findings:{repeated_calls:[{tool:'search_logs',argument_hash:'same',count:3}],failed_tool_calls:[],slowest_steps:[],token_share:[]},unknowns:[]},'three identical agent calls'],
 ['ListReleasesOutput',{...read,releases:[{service:'checkout',version:'1.4.1',first_seen:at,last_seen:at,current:true,concurrent:false,traffic_share:1,before:{error_rate:0,p95_ms:210},after:{error_rate:.2,p95_ms:1840},new_failure_ids:['opaque-project-F']}],has_more:false},'release onset and new failure'],
 ['GetServiceMapOutput',{...read,nodes:[{name:'orders-db',kind:'database',calls:5,error_rate:1,p95_ms:3,unit:'spans'}],edges:[{from:'checkout',to:'orders-db',calls:5,error_rate:1,p95_ms:3,example_operations:['db.query'],unit:'spans'}],unknown_callers:0},'checkout to database failing edge'],
 ['CheckTelemetryHealthOutput',{...read,silent_services:[{service:'billing',last_seen:'2026-10-12T08:00:00Z',usual_rate:1,unit:'spans/minute'}],orphan_spans:{count:0,share:0,services:[],unit:'spans'},semconv_gaps:[],unknown_service_share:0,schema_urls:[],retention:{oldest:at,days:30}},'silent billing last seen two hours ago'],
 ['GetMcpStatsOutput',{...read,totals,groups:[group],failure_classes:classes},'search_logs forty requests eight timeouts'],
 ['UpdateFailureStatusOutput',{failure:{...failure,status:'ignored',ignore_until:at,etag:'v2'}},'ignored status and new etag'],
 ['UpdateFailureStatusOutput',{failure:{...failure,status:'resolved',etag:'v3'}},'resolved status for recurrence detection'],
];
for(const [name,value,label]of cases){assertValid(V(name),value,label);if(name.endsWith('Output')&&name!=='UpdateFailureStatusOutput'){const missing={...value};delete missing.coverage;assertInvalid(V(name),missing,`${label} requires coverage`);}}
for(const op of ['eq','neq','in','prefix','contains','exists','gt','gte','lt','lte'])assertValid(C('TelemetryMatcher'),{key:'http.status_code',op,...(op==='exists'?{}:op==='in'?{values:[200,500]}:{value:op==='gt'?400:'500'}),scope:'span'},`matcher ${op}`);
assertInvalid(C('TelemetryMatcher'),{key:'x',op:'regex',value:'x'},'unplanned matcher operator');
assertValid(C('ToolCoverage'),{...coverage,examined:null,matched:null,returned:null},'unknown coverage is null');
assertInvalid(C('ToolCoverage'),{...coverage,examined:-1},'negative examined count');
const inputCases=[['ListSessionsInput',{active_only:true,has_error:true},'failing active sessions'],['ListTracesInput',{session_id:'sess_bad',errors_only:true},'three failing session traces'],['GetTraceInput',{trace_id:trace,selection:'critical_path'},'checkout critical path'],['GetTraceInput',{trace_id:trace,selection:'errors_with_ancestors'},'db chain contextual root'],['SearchLogsInput',{group_by:'pattern',context:10},'timeout pattern count'],['ListMetricsInput',{kind:'histogram',unit:'s'},'histogram discovery'],['GetMetricSeriesInput',{metric_name:'http.server.request.duration',...window},'metric route cardinality'],['QueryMetricInput',{metric_name:'http.server.request.duration',aggregation:'p95'},'histogram p95 approximation'],['QueryMetricInput',{metric_name:'counter',function:'increase'},'counter cumulative increase'],['CiLogInput',{compare_to:'last_success'},'CI new failure and build regression'],['DisplayMcpDashboardInput',{tool_name:'search_logs',compare_to:'previous_window'},'dashboard shares MCP stats'],['FetchTelemetryInput',{view:'compare',a:{trace_id:trace},b:{session_id:'sess_ok'},since_cursor:'opaque',fields:['first_divergence']},'viewer incremental comparison'],['CreateAnnotationInput',{target:{kind:'failure',failure_id:'opaque-project-F'},text:'note',labels:['bookmark'],classification:'finding',idempotency_key:'retry'},'failure annotation visible on read'],['UpdateAnnotationInput',{id:'annotation',etag:'v1',labels:['bookmark']},'label only annotation update'],['UpdateFailureStatusInput',{failure_id:'opaque-project-F',etag:'v1',status:'ignored',ignore_until:at},'ignore status input'],['UpdateFailureStatusInput',{failure_id:'opaque-project-F',etag:'v2',status:'resolved'},'resolve status input']];
for(const[n,v,l]of inputCases)assertValid(V(n),v,l);
assertInvalid(V('TriageInput'),{matchers:Array.from({length:33},()=>({key:'x',op:'exists'}))},'at most32matchers');
assertInvalid(V('AggregateTelemetryInput'),{signal:'spans',measures:['count'],group_by:['a','b','c','d','e']},'at most4group keys');
assertInvalid(V('CreateAnnotationInput'),{target:{kind:'failure',failure_id:'opaque-project-F'},text:'note',labels:['x'.repeat(65)]},'annotation labels bounded');
assertInvalid(V('UpdateFailureStatusInput'),{failure_id:'opaque-project-F',etag:'v1',status:'closed'},'status closed rejected');
console.log(`analysis contracts: ${names.length} typed read routes, ${cases.length} answer-key output shapes, ${inputCases.length} upgraded input cases`);

const matcher = {key:'service.name',scope:'resource',op:'exists'};
for (const [name, base] of /** @type {Array<[string, Record<string, unknown>]>} */ ([
 ['CompareGroup',{}], ['MetricRatio',{metric_name:'requests'}],
 ['FetchTelemetryTracesInput',{view:'traces'}], ['FetchTelemetryTraceInput',{view:'trace',trace_id:trace}],
 ['FetchTelemetryLogsInput',{view:'logs'}], ['FetchTelemetryMcpStatsInput',{view:'mcp_stats'}],
])) {
 assertValid(V(name), {...base,matchers:Array(32).fill(matcher)}, `${name} accepts 32 matchers`);
 assertInvalid(V(name), {...base,matchers:Array(33).fill(matcher)}, `${name} rejects 33 matchers`);
}
assertValid(V('TriageInput'),{limit:50},'triage maximum page');
assertInvalid(V('TriageInput'),{limit:51},'triage rejects more than fifty');
for(const compare_to of ['previous_window','7.7.0',{server_version:'7.7.0'},{offset_minutes:60}])
 assertValid(V('GetMcpStatsInput'),{compare_to},'MCP comparison accepts window and version exactly once');
for(const [name,value] of cases.filter(([name])=>name!=='UpdateFailureStatusOutput')) {
 const paged={...value,has_more:true,next_cursor:'opaque',page_totals:{items:200}};
 assertValid(V(name),paged,`${name} retains paging metadata`);
}
